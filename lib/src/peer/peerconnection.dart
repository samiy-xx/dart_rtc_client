part of rtc_client;

abstract class PeerConnection extends GenericEventTarget<PeerEventListener>{
  static final _logger = new Logger("dart_rtc_client.PeerConnection");
  static const String SDP_OFFER = 'offer';
  static const String SDP_ANSWER = 'answer';
  static const String STRING_CHANNEL = "string_channel";
  static const String BLOB_CHANNEL = "blob_channel";
  static const String BYTE_CHANNEL = "byte_channel";

  final RtcPeerConnection _peer;
  final PeerManager _manager;

  String _channel;
  String _id;
  bool _isHost = false;

  String get id => _id;
  set id(String v) => _id = v;

  String get channel => _channel;
  set channel(String v) => _channel = v;

  RtcPeerConnection get peer => _peer;

  factory PeerConnection.create(PeerManager pm, RtcPeerConnection rpc) {
    PeerConnection pc;
    if (Browser.isFirefox) {
      pc = new SctpPeerConnection(pm, rpc);
    } else {
      pc = new TmpPeerConnection(pm, rpc);
    }
    return pc;
  }

  PeerConnection(PeerManager pm, RtcPeerConnection rpc) : _peer = rpc, _manager = pm {
    _peer.onIceCandidate.listen(_onIceCandidate);
    _peer.onNegotiationNeeded.listen(_onNegotiationNeeded);
    _peer.onIceConnectionStateChange.listen(_onIceChange);
    _peer.onSignalingStateChange.listen(_onStateChanged);
    _peer.onDataChannel.listen(_onNewDataChannelOpen);
  }

  void close() {
    _logger.finer("Closing peer");
    if (_peer.signalingState != PEER_CLOSED)
      _peer.close();
  }

  RtcDataChannel createStringChannel(String id, Map constraints) {
    return _createChannel(id, null, constraints);
  }

  RtcDataChannel createBlobChannel(String id, Map constraints) {
    return _createChannel(id, "blob", constraints);
  }

  RtcDataChannel createByteBufferChannel(String id, Map constraints) {
    return _createChannel(id, "arraybuffer", constraints);
  }

  RtcDataChannel _createChannel(String id, String binaryType, Map constraints) {
    var dc = _peer.createDataChannel(id, constraints);
    dc.onClose.listen(_onDataChannelClose);
    dc.onOpen.listen(_onDataChannelOpen);
    dc.onError.listen(_onDataChannelError);

    if (binaryType != null)
      dc.binaryType = binaryType;

    return dc;
  }

  void _onIceCandidate(RtcIceCandidateEvent c);
  void _onIceChange(Event c);
  void _onRTCError(String error);
  void _onNegotiationNeeded(Event e);
  void _onStateChanged(Event e);

  void _onDataChannelError(RtcDataChannelEvent e) {
    _logger.severe("_onDataChannelError $e");
  }

  void _onDataChannelOpen(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged(dc);
  }

  void _onDataChannelClose(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged(dc);
  }

  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    var channel = e.channel;
    channel.onClose.listen(_onDataChannelClose);
    channel.onOpen.listen(_onDataChannelOpen);
    channel.onError.listen(_onDataChannelError);
    _logger.finer("New data channel (${e.channel.label}) opened by remote peer");
  }

  void _signalChannelStateChanged(RtcDataChannel channel) {
    _logger.finer("Datachannel (${channel.label}) state changed to ${channel.readyState}");
    window.setImmediate(() {
      listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
        l.onChannelStateChanged(this, channel, channel.readyState);
      });
    });
  }
}