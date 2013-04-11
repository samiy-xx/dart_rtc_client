part of rtc_client;

class ChannelClient implements RtcClient, DataSourceConnectionEventListener,
  PeerConnectionEventListener, PeerMediaEventListener, PeerDataEventListener,
  BinaryDataReceivedEventListener, BinaryDataSentEventListener {

  /* Keeps track of the initialization state of the client */
  InitializationState _currentState;

  /* Signal handler. TODO: Might need to remove some of the unused signalhandlers */
  StreamingSignalHandler _signalHandler;

  /* Manages the creation of peer connections */
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
  LocalMediaStream _ms = null;

  /* The channel we're in. TODO: We should support multiple channels? */
  String _channelId;

  /* our userid */
  String _myId;

  /* TODO: Ugh */
  String _otherId;

  bool _muteLocalLoopback = true;
  /**
   * Signal handler
   */
  StreamingSignalHandler get signalHandler => _signalHandler;

  /**
   * PeerManager
   */
  PeerManager get peerManager => _peerManager;

  /**
   * My id
   */
  String get myId => _myId;

  /**
   * Are you a channel owner
   */
  bool get isChannelOwner => _signalHandler.isChannelOwner;

  StreamController<MediaStreamAvailableEvent> _mediaStreamAvailableStreamController;
  Stream<MediaStreamAvailableEvent> get onRemoteMediaStreamAvailableEvent  => _mediaStreamAvailableStreamController.stream;

  StreamController<MediaStreamRemovedEvent> _mediaStreamRemovedStreamController;
  Stream<MediaStreamRemovedEvent> get onRemoteMediaStreamRemovedEvent  => _mediaStreamRemovedStreamController.stream;

  StreamController<InitializationStateEvent> _initializedController;
  Stream<InitializationStateEvent> get onInitializationStateChangeEvent => _initializedController.stream;

  StreamController<SignalingOpenEvent> _signalingOpenController;
  Stream<SignalingOpenEvent> get onSignalingOpenEvent => _signalingOpenController.stream;

  StreamController<SignalingCloseEvent> _signalingCloseController;
  Stream<SignalingCloseEvent> get onSignalingCloseEvent => _signalingCloseController.stream;

  StreamController<SignalingErrorEvent> _signalingErrorController;
  Stream<SignalingErrorEvent> get onSignalingErrorEvent => _signalingErrorController.stream;

  StreamController<PeerStateChangedEvent> _peerStateChangeController;
  Stream<PeerStateChangedEvent> get onPeerStateChangeEvent => _peerStateChangeController.stream;

  StreamController<IceGatheringStateChangedEvent> _iceGatheringStateChangeController;
  Stream<IceGatheringStateChangedEvent> get onIceGatheringStateChangeEvent => _iceGatheringStateChangeController.stream;

  StreamController<DataChannelStateChangedEvent> _dataChannelStateChangeController;
  Stream<DataChannelStateChangedEvent> get onDataChannelStateChangeEvent => _dataChannelStateChangeController.stream;

  StreamController<DataSourceMessageEvent> _dataSourceMessageController;
  Stream<DataSourceMessageEvent> get onDataSourceMessageEvent => _dataSourceMessageController.stream;

  StreamController<DataSourceCloseEvent> _dataSourceCloseController;
  Stream<DataSourceCloseEvent> get onDataSourceCloseEvent => _dataSourceCloseController.stream;

  StreamController<DataSourceOpenEvent> _dataSourceOpenController;
  Stream<DataSourceOpenEvent> get onDataSourceOpenEvent => _dataSourceOpenController.stream;

  StreamController<DataSourceErrorEvent> _dataSourceErrorController;
  Stream<DataSourceErrorEvent> get onDataSourceErrorEvent => _dataSourceErrorController.stream;

  StreamController<PacketEvent> _packetController;
  Stream<PacketEvent> get onPacketEvent => _packetController.stream;

  StreamController<RtcEvent> _binaryController;
  Stream<RtcEvent> get onBinaryEvent => _binaryController.stream;


  ChannelClient(DataSource ds) {
    _ds = ds;
    _ds.subscribe(this);

    _peerManager = new PeerManager();
    _peerManager.subscribe(this);

    _signalHandler = new StreamingSignalHandler(ds);

    _defaultGetUserMediaConstraints = new VideoConstraints();
    _defaultPeerCreationConstraints = new PeerConstraints();
    _defaultStreamConstraints = new StreamConstraints();

    _initializedController = new StreamController<InitializationStateEvent>.broadcast();
    _mediaStreamAvailableStreamController = new StreamController.broadcast();
    _mediaStreamRemovedStreamController = new StreamController.broadcast();
    _signalingOpenController = new StreamController.broadcast();
    _signalingCloseController = new StreamController.broadcast();
    _signalingErrorController = new StreamController.broadcast();
    _peerStateChangeController = new StreamController.broadcast();
    _iceGatheringStateChangeController = new StreamController.broadcast();
    _dataChannelStateChangeController = new StreamController.broadcast();
    _dataSourceMessageController = new StreamController.broadcast();
    _dataSourceCloseController = new StreamController.broadcast();
    _dataSourceOpenController = new StreamController.broadcast();
    _dataSourceErrorController = new StreamController.broadcast();
    _packetController = new StreamController.broadcast();
    _binaryController = new StreamController.broadcast();

    _signalHandler.registerHandler(PACKET_TYPE_JOIN, _joinPacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_ID, _idPacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_BYE, _byePacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_CHANNEL, _channelPacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_CONNECTED, _connectionSuccessPacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_CHANNELMESSAGE, _defaultPacketHandler);
    _signalHandler.registerHandler(PACKET_TYPE_CHANGENICK, _defaultPacketHandler);
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
        // TODO: Fix, this should take a map, but it's wrong in dartlang. https://code.google.com/p/dart/issues/detail?id=8061
        window.navigator.getUserMedia(audio: con.audio, video: con.video).then((LocalMediaStream stream) {
          _ms = stream;
          _peerManager.setLocalStream(stream);
          _signalHandler.initialize();

          _setState(InitializationState.MEDIA_READY);
          _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(stream, null, true));
        });
      } else {
        _setState(InitializationState.NOT_READY);
        return;
      }
    } else {
      _signalHandler.initialize();
    }

    window.onBeforeUnload.listen((event) {
      window.setImmediate(() {
        _signalHandler.close();
        _peerManager.closeAll();
      });
    });
  }

  ChannelClient setMuteLocalLoopback(bool b) {
    _muteLocalLoopback = b;
    return this;
  }
  /**
   * Implements RtcClient setRequireAudio
   */
  ChannelClient setRequireAudio(bool b) {
    _defaultGetUserMediaConstraints.audio = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireVideo
   */
  ChannelClient setRequireVideo(bool b) {
    _defaultGetUserMediaConstraints.video = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireDataChannel
   */
  ChannelClient setRequireDataChannel(bool b) {
    _defaultPeerCreationConstraints.dataChannelEnabled = b;
    _signalHandler.setDataChannelsEnabled(b);
    return this;
  }

  ChannelClient setReliableDataChannel(bool b) {
    _peerManager.reliableDataChannels = b;
    return this;
  }
  /**
   * Implements RtcClient setChannel
   */
  ChannelClient setChannel(String c) {
    _channelId = c;
    _signalHandler.channelId = c;
    return this;
  }

  /**
   * If true, Signalhandler will request peermanager to create peer connections
   * When ever a channel is joined.
   */
  ChannelClient setAutoCreatePeer(bool v) {
    _signalHandler._createPeerOnJoin = v;
    return this;
  }

  /**
   * Allows to set constraints for getUserMedia
   */
  ChannelClient setDefaultVideoConstraints(VideoConstraints vc) {
    _defaultGetUserMediaConstraints = vc;
    return this;
  }

  /**
   * Allows to set constraints for peer creation
   */
  ChannelClient setDefaultPeerConstraints(PeerConstraints pc) {
    _defaultPeerCreationConstraints = pc;
    _peerManager.setPeerConstraints(pc);
    return this;
  }

  /**
   * Constraints for adding stream
   */
  ChannelClient setDefaultStreamConstraints(StreamConstraints sc) {
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
    _signalHandler.sendPacket(new ChannelJoinCommand.With(_myId, name));
  }

  /**
   * Change your id (nick)
   */
  void changeId(String newId) {
    _signalHandler.sendPacket(new ChangeNickCommand.With(_myId, newId));
  }

  /*
   * Sets the current initialization state.
   */
  void _setState(InitializationState state) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasSubscribers)
      _initializedController.add(new InitializationStateEvent(state));
  }

  void _setStateWithChannelData(InitializationState state, ChannelPacket p) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasSubscribers)
      _initializedController.add(new ChannelInitializationStateEvent(state, p.channelId, p.owner));
  }
  /**
   * Sets the userlimit on channel
   * The issuer has to be the channel owner
   */
  bool setChannelLimit(int l) {
    if (_channelId != null) {
      _signalHandler.sendPacket(new SetChannelVarsCommand.With(_myId, _channelId, l));
      return true;
    }

    return false;
  }

  /**
   * Creates a peer connections and sets the creator as the host
   */
  void createPeerConnection(String id) {
    PeerWrapper p = _peerManager.createPeer();
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
  PeerWrapper findPeer(String id) {
    return _peerManager.findWrapper(id);
  }

  /**
   * Request the server that users gets kicked out of channel
   */
  void disconnectUser() {
    if (isChannelOwner && _otherId != null) {
      _signalHandler.send(PacketFactory.get(new RemoveUserCommand.With(_otherId, _channelId)));
    }
  }

  /**
   * Requests the server to transmit the message to all users in channel
   */
  void sendChannelMessage(String message) {
    _signalHandler.send(PacketFactory.get(new ChannelMessage.With(_myId, _channelId, message)));
  }

  void sendString(String peerId, String message) {
    _getDataPeerWrapper(peerId).sendString(message);
  }

  /**
   * Sends a blob to peer
   */
  void sendBlob(String peerId, Blob data) {
    throw new UnsupportedError("sendBlob is a work in progress");
  }

  Future<int> sendFile(String peerId, ArrayBuffer data) {
      return _getDataPeerWrapper(peerId).sendBuffer(data, BINARY_TYPE_FILE, true);
  }

  /**
   * Sends an arraybuffer to peer
   */
  Future<int> sendArrayBufferReliable(String peerId, ArrayBuffer data) {
      return _getDataPeerWrapper(peerId).sendBuffer(data, BINARY_TYPE_CUSTOM, true);
  }

  void sendArrayBufferUnReliable(String peerId, ArrayBuffer data) {
    if (_peerManager.reliableDataChannels)
      throw new Exception("Can not send unreliable data with reliable channel");
    _getDataPeerWrapper(peerId).sendBuffer(data, BINARY_TYPE_CUSTOM, false);
  }

  PeerWrapper _getPeerWrapper(String peerId) {
    PeerWrapper w = _peerManager.findWrapper(peerId);
    if (w == null)
      throw new PeerWrapperNullException("Peer wrapper null: $peerId");
    return w;
  }

  /**
   * Sends an arraybufferview to peer
   */
  Future<int> sendArrayBufferViewReliable(String peerId, ArrayBufferView data) {
    return sendArrayBufferReliable(peerId, data.buffer);
  }

  void sendArrayBufferViewUnReliable(String peerId, ArrayBufferView data) {
    sendArrayBufferUnReliable(peerId, data.buffer);
  }

  DataPeerWrapper _getDataPeerWrapper(String peerId) {
    try {
      PeerWrapper w = _getPeerWrapper(peerId);
      if (!(w is DataPeerWrapper))
        throw new PeerWrapperTypeException("Peer wrapper is not DataPeerWrapper type");
      return w;
    } on PeerWrapperNullException catch (e) {
      new Logger().Error("$e");
      throw e;
    } on PeerWrapperTypeException catch (e) {
      new Logger().Error("$e");
      throw e;
    }
  }

  void _defaultPacketHandler(Packet p) {
    PeerWrapper pw = _peerManager.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  void _connectionSuccessPacketHandler(ConnectionSuccessPacket p) {
    _myId = p.id;
    if (_channelId != null)
      joinChannel(_channelId);
    _setState(InitializationState.REMOTE_READY);
  }

  /*
   * TODO: Needs a stream controller and event
   */
  void _channelPacketHandler(ChannelPacket p) {
    PeerWrapper pw = _peerManager.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));

    _setStateWithChannelData(InitializationState.CHANNEL_READY, p);
  }

  /*
   * TODO: Needs a stream controller and event
   */
  void _joinPacketHandler(JoinPacket p) {
    new Logger().Debug("channelclient.dart Joinpackethandler received ${p.id}");
    _otherId = p.id;
    PeerWrapper pw = _peerManager.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  /*
   * TODO: Needs a stream controller and event
   */
  void _idPacketHandler(IdPacket p) {
    _otherId = p.id;
    PeerWrapper pw = _peerManager.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  /*
   * TODO: Needs a stream controller and event
   */
  void _byePacketHandler(ByePacket p) {
    PeerWrapper pw = _peerManager.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));

    if (_mediaStreamRemovedStreamController.hasSubscribers)
      _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
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
  void onChannelStateChanged(DataPeerWrapper p, String state){
    if (_dataChannelStateChangeController.hasSubscribers)
      _dataChannelStateChangeController.add(new DataChannelStateChangedEvent(p, state));
  }

  /**
   * Implements PeerDataEventListener onPacket
   */
  void onPacket(DataPeerWrapper pw, Packet p) {
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  /**
   * Remote media stream available from peer
   */
  void onRemoteMediaStreamAvailable(MediaStream ms, PeerWrapper pw, bool main) {
   if (_mediaStreamAvailableStreamController.hasSubscribers)
     _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(ms, pw));
  }

  /**
   * Media stream was removed
   */
  void onRemoteMediaStreamRemoved(PeerWrapper pw) {
    if (_mediaStreamRemovedStreamController.hasSubscribers)
      _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
  }

  /**
   * Implements PeerConnectionEventListener onPeerCreated
   * TODO : Cant i do this somewhere else?
   */
  void onPeerCreated(PeerWrapper pw) {
    if (pw is DataPeerWrapper) {
      try {
        DataPeerWrapper dpw = pw;
        dpw.binaryReader.subscribe(this);
        dpw.binaryWriter.subscribe(this);
      } catch(e) {
        new Logger().Error("Error: $e");
      }
      //dpw.binaryWriter.subscribe(this);
      pw.subscribe(this);
    }
  }
  /**
   * Implements PeerConnectionEventListener onPeerStateChanged
   */
  void onPeerStateChanged(PeerWrapper pw, String state) {
    if (_peerStateChangeController.hasSubscribers)
      _peerStateChangeController.add(new PeerStateChangedEvent(pw, state));
  }

  /**
   * Implements PeerConnectionEventListener onIceGatheringStateChanged
   */
  void onIceGatheringStateChanged(PeerWrapper pw, String state) {
    if (_iceGatheringStateChangeController.hasSubscribers)
      _iceGatheringStateChangeController.add(new IceGatheringStateChangedEvent(pw, state));
  }

  /**
   * Implements DataSourceConnectionEventListener onDataSourceMessage
   */
  void onDataSourceMessage(String m) {
    if (_dataSourceMessageController.hasSubscribers)
      _dataSourceMessageController.add(new DataSourceMessageEvent(m));
  }

  /**
   * implements DataSourceConnectionEventListener onCloseDataSource
   */
  void onCloseDataSource(String m) {
    if (_dataSourceCloseController.hasSubscribers)
      _dataSourceCloseController.add(new DataSourceCloseEvent(m));

    if (_signalingCloseController.hasSubscribers)
      _signalingCloseController.add(new SignalingCloseEvent(m));
  }

  /**
   * implements DataSourceConnectionEventListener onOpenDataSource
   */
  void onOpenDataSource(String m) {
    if (_dataSourceOpenController.hasSubscribers)
      _dataSourceOpenController.add(new DataSourceOpenEvent(m));

    if (_signalingOpenController.hasSubscribers)
      _signalingOpenController.add(new SignalingOpenEvent(m));
  }

  /**
   * implements DataSourceConnectionEventListener onDataSourceError
   */
  void onDataSourceError(String e) {
    if (_dataSourceErrorController.hasSubscribers)
      _dataSourceErrorController.add(new DataSourceErrorEvent(e));

    if (_signalingErrorController.hasSubscribers)
      _signalingErrorController.add(new SignalingErrorEvent(e));
  }

  //void onPeerPacket(PeerWrapper pw, PeerPacket p) {
  //  if (_binaryController.hasSubscribers) {
  //    _binaryController.add(new BinaryPeerPacketEvent(pw, p));
  //  }
  //}

  /**
   * Implements BinaryDataSentEventListener onWriteChunk
   */
  void onWriteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinaryChunkWriteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataSentEventListener onWroteChunk
   */
  void onWroteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinaryChunkWroteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerString
   */
  void onPeerString(PeerWrapper pw, String s) {

  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerFile
   */
  void onPeerFile(PeerWrapper pw, Blob b) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinaryFileCompleteEvent(pw, b));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerBuffer
   */
  void onPeerBuffer(PeerWrapper pw, ArrayBuffer b) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinaryBufferCompleteEvent(pw, b));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerReadChunk
   */
  void onPeerReadChunk(PeerWrapper pw, ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinaryChunkEvent(pw, buffer, signature, sequence, totalSequences, bytes, bytesTotal));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerSendSuccess
   */
  void onPeerSendSuccess(int signature, int sequence) {
    if (_binaryController.hasSubscribers)
      _binaryController.add(new BinarySendCompleteEvent(signature, sequence));
  }
}