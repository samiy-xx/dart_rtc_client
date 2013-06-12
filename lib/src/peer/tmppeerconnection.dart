part of rtc_client;

class TmpPeerConnection extends PeerConnection {
  static final _logger = new Logger("dart_rtc_client.TmpPeerConnection");

  RtcDataChannel _dataChannel;
  UDPDataWriter _binaryWriter;
  UDPDataReader _binaryReader;

  bool _isReliable = false;
  String _channelState = null;

  List<dynamic> _ices;
  bool _hasLocalSet = false;
  UDPDataWriter get binaryWriter => _binaryWriter;
  UDPDataReader get binaryReader => _binaryReader;


  set isReliable(bool r) => _isReliable = r;


  TmpPeerConnection(PeerManager pm, RtcPeerConnection p) : super(pm, p) {
    _ices = new List<dynamic>();
    _binaryWriter = new UDPDataWriter(this);
    _binaryReader = new UDPDataReader(this);
  }

  void setAsHost(bool value) {
    super.setAsHost(value);
    initChannel();
  }

  void initialize() {
    if (_isHost)
      _sendOffer();
  }

  void close() {
    _dataChannel.close();
    super.close();
  }

  void subscribeToReaders(BinaryDataEventListener l) {
    binaryReader.subscribe(l);
  }

  void subscribeToWriters(BinaryDataEventListener l) {
    binaryWriter.subscribe(l);
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
      _dataChannel.binaryType = "arraybuffer";
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

  /*void setRemoteSessionDescription(RtcSessionDescription sdp) {
    _peer.setRemoteDescription(sdp).then((val) {
      _logger.fine("Setting remote description was success ${sdp.type}");
      if (sdp.type == SDP_OFFER)
        _sendAnswer();
    })
    .catchError((e) {
      _logger.severe("setting remote description failed ${sdp.type} ${e} ${sdp.sdp}");
    });
  }*/

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
    if (c.candidate != null) {
      _manager.getSignaler().sendIceCandidate(this, c.candidate);
    } else {
      _logger.severe("ICE Candidate null");
    }
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
}