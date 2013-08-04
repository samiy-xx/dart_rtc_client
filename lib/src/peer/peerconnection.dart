part of rtc_client;

abstract class PeerConnection extends GenericEventTarget<PeerEventListener>{
  static final _logger = new Logger("dart_rtc_client.PeerConnection");
  static const String SDP_OFFER = 'offer';
  static const String SDP_ANSWER = 'answer';
  static const String STRING_CHANNEL = "string_channel";
  static const String BLOB_CHANNEL = "blob_channel";
  static const String RELIABLE_BYTE_CHANNEL = "reliable_byte_channel";
  static const String UNRELIABLE_BYTE_CHANNEL = "unreliable_byte_channel";
  final RtcPeerConnection _peer;
  final PeerManager _manager;

  String _channel;
  String _id;
  bool _isHost = false;

  String get id => _id;
  String get channel => _channel;
  RtcPeerConnection get peer => _peer;

  set id(String v) => _id = v;
  set channel(String v) => _channel = v;

  factory PeerConnection.create(PeerManager pm, RtcPeerConnection rpc) {
    PeerConnection pc;
    if (Browser.isFirefox) {
      pc = new SctpPeerConnection(pm, rpc);
    } else {
      //pc = new TmpPeerConnection(pm, rpc);
      pc = new ChromeSctpPeerConnection(pm, rpc);
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

  void setAsHost(bool value) {
    _isHost = value;
  }

  void initialize();
  void addStream(MediaStream ms);
  void initChannel();
  void addRemoteIceCandidate(RtcIceCandidate candidate);
  void subscribeToReaders(BinaryDataEventListener l);
  void subscribeToWriters(BinaryDataEventListener l);
  void sendString(String s);
  Future<int> sendBlob(Blob b);
  Future<int> sendFile(File f);
  Future<int> sendBuffer(ByteBuffer buf, int packetType, bool reliable);
  void _sendOffer();
  void _sendAnswer();
  void _onIceCandidate(RtcIceCandidateEvent c);
  void _onNegotiationNeeded(Event e);

  void setRemoteSessionDescription(RtcSessionDescription sdp) {
    _peer.setRemoteDescription(sdp).then((val) {
      _logger.fine("Setting remote description was success ${sdp.type}");
      if (sdp.type == SDP_OFFER)
        _sendAnswer();
    })
    .catchError((e) {
      _logger.severe("setting remote description failed ${sdp.type} ${e} ${sdp.sdp}");
    });
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

  void _onIceChange(Event c) {
    _logger.fine("ICE Change ${c} (ice gathering state ${_peer.iceGatheringState}) (ice state ${_peer.iceConnectionState})");
  }

  void _onRTCError(String error) {
    _logger.severe("RTC ERROR : $error");
  }

  void _onStateChanged(Event e) {
    if (_peer.signalingState == PEER_STABLE) {

    }
  }

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