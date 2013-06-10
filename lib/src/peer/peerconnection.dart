part of rtc_client;

class PeerConnection extends GenericEventTarget<PeerEventListener>{
  const String SDP_OFFER = 'offer';
  const String SDP_ANSWER = 'answer';
  static final _logger = new Logger("dart_rtc_client.PeerConnection");
  final RtcPeerConnection _peer;
  final PeerManager _manager;
  RtcDataChannel _dataChannel;
  BinaryDataWriter _binaryWriter;
  BinaryDataReader _binaryReader;
  bool _isHost = false;
  bool _isReliable = false;
  String _channelState = null;
  String _channel;
  String _id;
  List<dynamic> _ices;
  bool _hasLocalSet = false;
  BinaryDataWriter get binaryWriter => _binaryWriter;
  BinaryDataReader get binaryReader => _binaryReader;
  RtcPeerConnection get peer => _peer;

  set isReliable(bool r) => _isReliable = r;
  String get id => _id;
  set id(String v) => _id = v;
  String get channel => _channel;
  set channel(String v) => _channel = v;

  PeerConnection(PeerManager pm, RtcPeerConnection p) : _manager = pm, _peer = p {
    _ices = new List<dynamic>();
    _peer.onIceCandidate.listen(_onIceCandidate);
    _peer.onNegotiationNeeded.listen(_onNegotiationNeeded);
    _peer.onIceConnectionStateChange.listen(_onIceChange);
    _peer.onSignalingStateChange.listen(_onStateChanged);
    _peer.onDataChannel.listen(_onNewDataChannelOpen);
    if (Browser.isFirefox) {
      _binaryWriter = new TCPDataWriter(this);
      _binaryReader = new TCPDataReader(this);
    } else {
      _binaryWriter = new UDPDataWriter(this);
      _binaryReader = new UDPDataReader(this);
    }
    //_binaryWriter.subscribe(this);
    //_binaryReader.subscribe(this);
    if (Browser.isFirefox)
      _isReliable = true;
  }

  void setAsHost(bool value) {
    _isHost = value;
    initChannel();
  }

  void initialize() {
    if (_isHost)
      _sendOffer();
  }

  void setBinaryType(String type) {
    if (_dataChannel != null)
      _dataChannel.binaryType = type;
  }

  void close() {
    _logger.severe("(peerwrapper.dart) Closing peer");
    if (_peer.signalingState != PEER_CLOSED)
      _peer.close();
  }

  void addStream(MediaStream ms) {
    if (ms == null)
      throw new Exception("MediaStream was null");
    _logger.fine("Adding stream to peer $id");
    try {
      //_peer.addStream(ms, _manager.getStreamConstraints().toMap());
      _peer.addStream(ms);
      if (Browser.isFirefox) {
        initialize();
      }
    } on DomException catch(e, s) {
      _logger.severe("DOM Error setting constraints: $e ${_manager.getStreamConstraints().toMap().toString()}");
      _peer.addStream(ms);
    } on Exception catch (e) {
      _logger.severe("Exception on adding stream $e");
    } catch(e) {
      _logger.severe("Exception on adding stream $e");
    }
  }

  void initChannel() {
    if (!_isHost)
      return;

    _logger.fine("Initializing send data channel");
    try {
      _dataChannel = _peer.createDataChannel("channel", !Browser.isFirefox ? {'reliable': _isReliable} : {});
      //_dataChannel = _peer.createDataChannel("channel", {'reliable': false});
      _dataChannel.binaryType = Browser.isFirefox ? "blob" : "arraybuffer";
      _dataChannel.onClose.listen(_onDataChannelClose);
      _dataChannel.onOpen.listen(_onDataChannelOpen);
      _dataChannel.onError.listen(_onDataChannelError);

      _binaryWriter.dataChannel = _dataChannel;
      _binaryReader.dataChannel = _dataChannel;
    } on Exception catch(e, s) {
      _logger.severe("$e");
      _logger.fine("$s");
    }
  }

  /*void setSessionDescription(RtcSessionDescription sdp) {
    _peer.setLocalDescription(sdp).then((val) {
        _logger.fine("(peerwrapper.dart) Setting local description was success");
    }).catchError((e) {
        _logger.severe("(peerwrapper.dart) setting local description failed ${e}");
    });
  }*/

  void setRemoteSessionDescription(RtcSessionDescription sdp) {
    _peer.setRemoteDescription(sdp).then((val) {
      _logger.fine("(peerwrapper.dart) Setting remote description was success ${sdp.type}");
      if (sdp.type == SDP_OFFER)
        _sendAnswer();
    })
    .catchError((e) {
      _logger.severe("(peerwrapper.dart) setting remote description failed ${sdp.type} ${e} ${sdp.sdp}");
    });


  }

  void addRemoteIceCandidate(RtcIceCandidate candidate) {
      if (candidate == null)
        throw new Exception("RtcIceCandidate was null");

      if (_peer.signalingState != PEER_CLOSED) {
        _logger.fine("(peerwrapper.dart) Receiving remote ICE Candidate ${candidate.candidate}");
        if (_hasLocalSet)
          _peer.addIceCandidate(candidate);
        else
          _ices.add(candidate);
      }
  }

  void sendString(String s) {
    _dataChannel.send(s);
  }

  Future<int> sendBlob(Blob b) {
    return _binaryWriter.sendFile(b);
  }

  Future<int> sendFile(File f) {
    return sendBlob(f);
  }

  Future<int> sendBuffer(ByteBuffer buf, int packetType, bool reliable) {
    return _binaryWriter.send(buf, packetType, reliable);
  }

  void _onIceCandidate(RtcIceCandidateEvent c) {

    if (!Browser.isFirefox) {
      if (c.candidate != null) {
        //IcePacket ice = new IcePacket.With(c.candidate.candidate, c.candidate.sdpMid, c.candidate.sdpMLineIndex, id);
        _manager.getSignaler().sendIceCandidate(this, c.candidate);
        //_manager._sendPacket(PacketFactory.get(ice));
      } else {
        _logger.severe("ICE Candidate null");
      }
    }
  }

  void _onIceChange(Event c) {
    _logger.fine("(peerwrapper.dart) ICE Change ${c} (ice gathering state ${_peer.iceGatheringState}) (ice state ${_peer.iceConnectionState})");
  }

  void _onRTCError(String error) {
    _logger.severe("(peerwrapper.dart) RTC ERROR : $error");
  }

  void _sendOffer() {
    _peer.createOffer()
      .then(_setLocalAndSend)
      .catchError((e) {
        _logger.severe("(peerwrapper.dart) Error creating offer $e");
      });
  }

  void _sendAnswer() {
    _peer.createAnswer()
      .then(_setLocalAndSend)
      .catchError((e) {
        _logger.severe("(peerwrapper.dart) Error creating answer $e");
      });
  }

  void _setLocalAndSend(RtcSessionDescription sd) {
    sd = Util.hackTheSdp(sd);
    _peer.setLocalDescription(sd).then((_) {
      _hasLocalSet = true;
      _setQueuedIces();
      _logger.fine("(peerwrapper.dart) Setting local description was success");
      _manager.getSignaler().sendSessionDescription(this, sd);
    }).catchError((e) {
        _logger.severe("(peerwrapper.dart) setting local description failed ${e}");
    });
  }
  void _setQueuedIces() {
    _ices.forEach((i) => _peer.addIceCandidate(i));
  }

  void _onNegotiationNeeded(Event e) {
    _logger.info("onNegotiationNeeded");

    if (_isHost)
      _sendOffer();
  }

  void _onStateChanged(Event e) {
    if (_peer.signalingState == PEER_STABLE) {

    }
  }

  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    _logger.fine("--- Receiving incoming data channel");;

    _dataChannel = e.channel;
    _dataChannel.onClose.listen(_onDataChannelClose);
    _dataChannel.onOpen.listen(_onDataChannelOpen);
    _dataChannel.onError.listen(_onDataChannelError);
    //_dataChannel.binaryType = "arraybuffer";
    _binaryWriter.dataChannel = _dataChannel;
    _binaryReader.dataChannel = _dataChannel;
  }

  void _onDataChannelOpen(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged();
    _logger.fine("DataChannelOpen ${dc.label}");
  }

  void _onDataChannelClose(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged();
    _logger.fine(" DataChannelClose ${dc.label}");
  }

  void _onDataChannelError(RtcDataChannelEvent e) {
    _logger.severe("DataChannelError $e");
  }

  void _signalChannelStateChanged() {

    if (_dataChannel.readyState != _channelState) {
      listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
        l.onChannelStateChanged(this, _dataChannel.readyState);
      });
      _channelState = _dataChannel.readyState;
    }
  }

}