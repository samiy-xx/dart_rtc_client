part of rtc_client;

/* Clean up by starting from scratch */
class PeerClient implements RtcClient,
  PeerConnectionEventListener, PeerMediaEventListener, PeerDataEventListener,
  BinaryDataReceivedEventListener, BinaryDataSentEventListener {

  static final _logger = new Logger("dart_rtc_client.PeerClient");
  /* Keeps track of the initialization state of the client */
  InitializationState _currentState;

  /** Signaling */
  Signaler _signalHandler;

  /** Manages the creation of peer connections */
  PeerManager _peerManager;

  /* Datasource, TODO: Rename maybe, Datasource sounds more like database */
  DataSource _ds;

  /* Constraints for getUserMedia */
  VideoConstraints _defaultGetUserMediaConstraints;

  /* Constraints for creating peer */
  PeerConstraints _defaultPeerCreationConstraints;

  /* Constraints for adding stream to peer */
  StreamConstraints _defaultStreamConstraints;

  /* MediaStream from our own webcam etc... */
  MediaStream _ms = null;

  bool _createPeerOnJoin = true;

  /* The channel we're in. TODO: We should support multiple channels? */
  String _channelId;

  /* our userid */
  String _myId;

  /* TODO: Ugh */
  //String _otherId;

  bool _muteLocalLoopback = true;

  /**
   * PeerManager
   */
  PeerManager get peerManager => _peerManager;

  /**
   * My id
   */
  String get myId => _myId;

  bool get isChannelOwner => _signalHandler.isChannelOwner;

  StreamController<MediaStreamAvailableEvent> _mediaStreamAvailableStreamController;
  Stream<MediaStreamAvailableEvent> get onRemoteMediaStreamAvailableEvent  => _mediaStreamAvailableStreamController.stream;

  StreamController<MediaStreamRemovedEvent> _mediaStreamRemovedStreamController;
  Stream<MediaStreamRemovedEvent> get onRemoteMediaStreamRemovedEvent  => _mediaStreamRemovedStreamController.stream;

  StreamController<InitializationStateEvent> _initializedController;
  Stream<InitializationStateEvent> get onInitializationStateChangeEvent => _initializedController.stream;

  StreamController<PeerStateChangedEvent> _peerStateChangeController;
  Stream<PeerStateChangedEvent> get onPeerStateChangeEvent => _peerStateChangeController.stream;

  StreamController<IceGatheringStateChangedEvent> _iceGatheringStateChangeController;
  Stream<IceGatheringStateChangedEvent> get onIceGatheringStateChangeEvent => _iceGatheringStateChangeController.stream;

  StreamController<DataChannelStateChangedEvent> _dataChannelStateChangeController;
  Stream<DataChannelStateChangedEvent> get onDataChannelStateChangeEvent => _dataChannelStateChangeController.stream;

  StreamController<RtcEvent> _binaryController;
  Stream<RtcEvent> get onBinaryEvent => _binaryController.stream;

  Stream<SignalingStateEvent> get onSignalingStateChanged => _signalHandler.onSignalingStateChanged;
  Stream<ServerEvent> get onServerEvent=> _signalHandler.onServerEvent;

  PeerClient(DataSource ds) {
    libLogger.fine("Test");
    _ds = ds;

    _peerManager = new PeerManager();
    _peerManager.subscribe(this);

    _signalHandler = new SimpleSignalHandler(ds);
    _peerManager.signaler = _signalHandler;

    _defaultGetUserMediaConstraints = new VideoConstraints();
    _defaultPeerCreationConstraints = new PeerConstraints();
    _defaultStreamConstraints = new StreamConstraints();

    _initializedController = new StreamController<InitializationStateEvent>();
    _mediaStreamAvailableStreamController = new StreamController();
    _mediaStreamRemovedStreamController = new StreamController();

    _peerStateChangeController = new StreamController();
    _iceGatheringStateChangeController = new StreamController();
    _dataChannelStateChangeController = new StreamController();

    _binaryController = new StreamController();

    onServerEvent.listen((ServerEvent e) => _serverEventHandler(e));
    onSignalingStateChanged.listen((SignalingStateEvent e) => _signalingEventHandler(e));
  }

  /**
   * Initializes client and tells signalhandler to connect.
   */
  void initialize([VideoConstraints constraints]) {
    VideoConstraints con = ?constraints ? constraints : _defaultGetUserMediaConstraints;
    if (!con.audio && !con.video && !_defaultPeerCreationConstraints.dataChannelEnabled)
      throw new Exception("Must require either video, audio or data channel");

    // If either is set, need to request permission for audio and/or video
    if ((con.audio || con.video) && _ms == null) {
      if (MediaStream.supported) {
        _logger.fine("Requesting userMedia");
        // TODO: Fix, this should take a map, but it's wrong in dartlang. https://code.google.com/p/dart/issues/detail?id=8061
        window.navigator.getUserMedia(audio: con.audio, video: con.video).then((MediaStream stream) {

          _ms = stream;
          _peerManager.setLocalStream(stream);
          _signalHandler.initialize();

          _setState(InitializationState.MEDIA_READY);
          _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(stream, null, true));
        }).catchError((e) {
          _logger.severe("Error initializing $e");
          if (e is NavigatorUserMediaError) {
            window.alert("Unable to access user media. Is webcam or microphone used by another process?");
          }
        });
      } else {
        _setState(InitializationState.NOT_READY);
        return;
      }
    } else {
      _signalHandler.initialize();
    }

    /*window.onBeforeUnload.listen((_) {
      window.setImmediate(() {
        _signalHandler.close();
        _peerManager.closeAll();
      });
    });*/
  }

  void close() {
    _signalHandler.close();
    _peerManager.closeAll();
  }

  PeerClient setMuteLocalLoopback(bool b) {
    _muteLocalLoopback = b;
    return this;
  }
  /**
   * Implements RtcClient setRequireAudio
   */
  PeerClient setRequireAudio(bool b) {
    _defaultGetUserMediaConstraints.audio = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireVideo
   */
  PeerClient setRequireVideo(bool b) {
    _defaultGetUserMediaConstraints.video = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireDataChannel
   */
  PeerClient setRequireDataChannel(bool b) {
    _defaultPeerCreationConstraints.dataChannelEnabled = b;
    _peerManager.dataChannelsEnabled = b;
    return this;
  }

  PeerClient setReliableDataChannel(bool b) {
    _peerManager.reliableDataChannels = b;
    return this;
  }

  /**
   * Implements RtcClient setChannel
   */
  PeerClient setChannel(String c) {
    _channelId = c;
    _signalHandler.channelId = c;
    return this;
  }

  /**
   * If true, Signalhandler will request peermanager to create peer connections
   * When ever a channel is joined.
   */
  PeerClient setAutoCreatePeer(bool v) {
    _createPeerOnJoin = v;
    _signalHandler.createPeerOnJoin = v;
    return this;
  }

  /**
   * Allows to set constraints for getUserMedia
   */
  PeerClient setDefaultVideoConstraints(VideoConstraints vc) {
    _defaultGetUserMediaConstraints = vc;
    return this;
  }

  /**
   * Allows to set constraints for peer creation
   */
  PeerClient setDefaultPeerConstraints(PeerConstraints pc) {
    _defaultPeerCreationConstraints = pc;
    _peerManager.setPeerConstraints(pc);
    return this;
  }

  /**
   * Constraints for adding stream
   */
  PeerClient setDefaultStreamConstraints(StreamConstraints sc) {
    _defaultStreamConstraints = sc;
    _peerManager.setStreamConstraints(sc);
    return this;
  }

  /**
   * Clears all Stun and Turn server entries.
   */
  void clearStun() {
    _peerManager._serverConstraints.clear();
  }

  /**
   * Creates a Stun server entry and adds it to the peermanager
   */
  StunServer createStunEntry(String address, String port) {
    StunServer ss = new StunServer();
    ss.setAddress(address);
    ss.setPort(port);
    _peerManager._serverConstraints.addStun(ss);
    return ss;
  }

  /**
   * Creates a Turn server entry and adds it to the peermanager
   */
  TurnServer createTurnEntry(String address, String port, String userName, String password) {
    TurnServer ts = new TurnServer();
    ts.setAddress(address);
    ts.setPort(port);
    ts.setUserName(userName);
    ts.setPassword(password);
    _peerManager._serverConstraints.addTurn(ts);
    return ts;
  }

  /**
   * Requests to join a channel
   */
  void joinChannel(String name) {
    _channelId = name;
    _signalHandler.joinChannel(_myId, name);
  }

  /**
   * Change your id (nick)
   */
  /* Should not assume that signal handler supports this */
  void changeId(String newId) {
    _signalHandler.changeId(_myId, newId);
  }

  /**
   * Sets the userlimit on channel
   * The issuer has to be the channel owner
   */
  /* Should not assume that signal handler supports this */
  bool setChannelLimit(int l) {
    return _signalHandler.setChannelLimit(_myId, _channelId, l);
  }

  /**
   * Creates a peer connections and sets the creator as the host
   */
  void createPeerConnection(String id) {
    PeerConnection p = _peerManager.createPeer();
    p.id = id;
    p.setAsHost(true);
  }

  /**
   * Finds if a peer connection with given id exists
   */
  bool peerWrapperExists(String id) {
    return findPeer(id) != null;
  }

  /**
   * Finds a peer connection with given id
   */
  PeerConnection findPeer(String id) {
    return _peerManager.findWrapper(id);
  }

  /**
   * Request the server that users gets kicked out of channel
   */
  /* Should not assume that signal handler supports this */
  void disconnectUser(String id) {
    if (isChannelOwner) {
      _signalHandler.send(PacketFactory.get(new RemoveUserCommand.With(id, _channelId)));
    }
  }

  /**
   * Requests the server to transmit the message to all users in channel
   */
  void sendChannelMessage(String message) {
    _signalHandler.send(PacketFactory.get(new ChannelMessage.With(_myId, _channelId, message)));
  }


  void sendString(String peerId, String message) {
    _getPeer(peerId).sendString(message);
  }

  /**
   * Sends a blob to peer
   */
  Future<int> sendBlob(String peerId, Blob blob) {
    var peer = _getPeer(peerId);
    return peer.sendBlob(blob);
  }

  Future<int> sendFile(String peerId, File f) {
    return sendBlob(peerId, f);
  }

  /**
   * Sends an arraybuffer to peer
   */
  Future<int> sendArrayBufferReliable(String peerId, ByteBuffer data) {
    var peer = _getPeer(peerId);
    return peer.sendBuffer(data, BINARY_TYPE_CUSTOM, true);
  }

  void sendArrayBufferUnReliable(String peerId, ByteBuffer data) {
    if (_peerManager.reliableDataChannels)
      throw new Exception("Can not send unreliable data with reliable channel");
    var peer = _getPeer(peerId);
    peer.sendBuffer(data, BINARY_TYPE_CUSTOM, false);
  }

  PeerConnection _getPeer(String peerId) {
    PeerConnection w = _peerManager.findWrapper(peerId);
    if (w == null)
      throw new PeerWrapperNullException("Peer wrapper null: $peerId");
    return w;
  }

  /*
   * Sets the current initialization state.
   */
  void _setState(InitializationState state) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasListener)
      _initializedController.add(new InitializationStateEvent(state));
  }

  void _setStateWithChannelData(InitializationState state, ServerJoinEvent e) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasListener)
      _initializedController.add(new ChannelInitializationStateEvent(state, e.channel, e.isOwner));
  }

  void _signalingEventHandler(SignalingStateEvent e) {
    _logger.fine("Signaling event $e");
    if (e is SignalingReadyEvent) {
      SignalingReadyEvent p = e;
      _myId = p.id;
      if (_channelId != null)
        joinChannel(_channelId);
      _setState(InitializationState.REMOTE_READY);
    }
  }

  void _serverEventHandler(ServerEvent e) {
    if (e is ServerJoinEvent) {
      _setStateWithChannelData(InitializationState.CHANNEL_READY, e);
    }

    else if (e is ServerParticipantJoinEvent) {
      ServerParticipantJoinEvent p = e;
      if (_createPeerOnJoin) {
        PeerConnection pc = _peerManager.createPeer();
        pc.id = p.id;
        pc.channel = p.channel;
        pc.setAsHost(true);

        if (_defaultGetUserMediaConstraints.audio || _defaultGetUserMediaConstraints.video) {
          MediaStream ms = peerManager.getLocalStream();
          if (ms != null)
            pc.addStream(ms);
        }

        if (_defaultPeerCreationConstraints.dataChannelEnabled) {
          pc.initChannel();
        }
      }
    }

    else if (e is ServerParticipantIdEvent) {
      ServerParticipantIdEvent p = e;
      if (_createPeerOnJoin) {
        PeerConnection pc = _peerManager.createPeer();
        pc.id = p.id;
        pc.channel = p.channel;

        if (_defaultGetUserMediaConstraints.audio || _defaultGetUserMediaConstraints.video) {
          MediaStream ms = peerManager.getLocalStream();
          if (ms != null)
            pc.addStream(ms);
        }
      }
    }

    else if (e is ServerParticipantLeftEvent) {
      ServerParticipantLeftEvent p = e;
      PeerConnection pw = _peerManager.findWrapper(p.id);

      if (_mediaStreamRemovedStreamController.hasListener)
        _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
    }

    else if (e is ServerParticipantStatusEvent) {

    }

    else if (e is ServerChannelMessageEvent) {

    }

    else if (e is ServerIceEvent) {
      ServerIceEvent sie = e;
      PeerConnection peer = _peerManager.findWrapper(sie.id);
      if (peer != null)
        peer.addRemoteIceCandidate(sie.candidate);
    }

    else if (e is ServerSessionDescriptionEvent) {
      ServerSessionDescriptionEvent ssde = e;
      PeerConnection peer = _peerManager.findWrapper(ssde.id);
      if (peer != null)
        peer.setRemoteSessionDescription(ssde.description);
    }
  }

  /**
   * Implements PeerDataEventListener onDateReceived
   * TODO : Do something with this
   */
  void onDataReceived(int buffered) {

  }

  /**
   * Implements PeerDataEventListener onChannelStateChanged
   */
  void onChannelStateChanged(PeerConnection p, RtcDataChannel c, String state){
    if (_dataChannelStateChangeController.hasListener)
      _dataChannelStateChangeController.add(new DataChannelStateChangedEvent(p, state));
  }

  /**
   * Remote media stream available from peer
   */
  void onRemoteMediaStreamAvailable(MediaStream ms, PeerConnection pw, bool main) {
   if (_mediaStreamAvailableStreamController.hasListener)
     _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(ms, pw));
  }

  /**
   * Media stream was removed
   */
  void onRemoteMediaStreamRemoved(PeerConnection pw) {
    if (_mediaStreamRemovedStreamController.hasListener)
      _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
  }

  /**
   * Implements PeerConnectionEventListener onPeerCreated
   * TODO : Cant i do this somewhere else?
   */
  void onPeerCreated(PeerConnection pc) {
      pc.subscribeToReaders(this);
      pc.subscribeToWriters(this);
      pc.subscribe(this);

  }
  /**
   * Implements PeerConnectionEventListener onPeerStateChanged
   */
  void onPeerStateChanged(PeerConnection pw, String state) {
    if (_peerStateChangeController.hasListener)
      _peerStateChangeController.add(new PeerStateChangedEvent(pw, state));
  }

  /**
   * Implements PeerConnectionEventListener onIceGatheringStateChanged
   */
  void onIceGatheringStateChanged(PeerConnection pw, String state) {
    if (_iceGatheringStateChangeController.hasListener)
      _iceGatheringStateChangeController.add(new IceGatheringStateChangedEvent(pw, state));
  }

  /**
   * Implements BinaryDataSentEventListener onWriteChunk
   */
  void onWriteChunk(PeerConnection pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkWriteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataSentEventListener onWroteChunk
   */
  void onWroteChunk(PeerConnection pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkWroteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerString
   */
  void onPeerString(PeerConnection pw, String s) {

  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerFile
   */
  void onPeerFile(PeerConnection pw, Blob b) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryFileCompleteEvent(pw, b));
  }

  void onPeerBlobChunk(PeerConnection pc, Blob b) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryBlobChunk(pc, b));
  }
  /**
   * Implements BinaryDataReceivedEventListener onPeerBuffer
   */
  void onPeerBuffer(PeerConnection pw, ByteBuffer b, int binaryType) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryBufferCompleteEvent(pw, b, binaryType));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerReadChunk
   */
  void onPeerReadUdpChunk(PeerConnection pw, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkEvent(pw, buffer, signature, sequence, totalSequences, bytes, bytesTotal, BINARY_PROTOCOL_UDP));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerReadChunk
   */
  void onPeerReadTcpChunk(PeerConnection pw, ByteBuffer buffer, int signature, int bytes, int bytesTotal) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkEvent(pw, buffer, signature, null, null, bytes, bytesTotal, BINARY_PROTOCOL_TCP));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerSendSuccess
   */
  void onPeerSendSuccess(int signature, int sequence) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinarySendCompleteEvent(signature, sequence));
  }
}