part of rtc_client;

class ChannelClient implements RtcClient, DataSourceConnectionEventListener,
  PeerConnectionEventListener, PeerMediaEventListener, PeerDataEventListener {
  InitializationState _currentState;

  StreamingSignalHandler _sh;
  PeerManager _pm;
  DataSource _ds;

  //bool _requireAudio = false;
  //bool _requireVideo = false;
  //bool _requireDataChannel = false;

  VideoConstraints _defaultGetUserMediaConstraints;
  PeerConstraints _defaultPeerCreationConstraints;
  StreamConstraints _defaultStreamConstraints;

  LocalMediaStream _ms = null;

  String _channelId;
  String _myId;
  String _otherId;

  /**
   * Signal handler
   */
  StreamingSignalHandler get signalHandler => _sh;

  /**
   * PeerManager
   */
  PeerManager get peerManager => _pm;

  /**
   * My id
   */
  String get myId => _myId;

  /**
   * Are you a channel owner
   */
  bool get isChannelOwner => _sh.isChannelOwner;

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

  ChannelClient(DataSource ds) {
    _ds = ds;
    _ds.subscribe(this);

    _pm = new PeerManager();
    _pm.subscribe(this);

    _sh = new StreamingSignalHandler(ds);

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
    _dataSourceMessageController = new StreamController.broadcast();
    _dataSourceCloseController = new StreamController.broadcast();
    _dataSourceOpenController = new StreamController.broadcast();
    _dataSourceErrorController = new StreamController.broadcast();
    _packetController = new StreamController.broadcast();

    _sh.registerHandler(PacketType.JOIN, _joinPacketHandler);
    _sh.registerHandler(PacketType.ID, _idPacketHandler);
    _sh.registerHandler(PacketType.BYE, _byePacketHandler);
    _sh.registerHandler(PacketType.CHANNEL, _channelPacketHandler);
    _sh.registerHandler(PacketType.CONNECTED, _connectionSuccessPacketHandler);
    _sh.registerHandler(PacketType.CHANNELMESSAGE, _defaultPacketHandler);
    _sh.registerHandler(PacketType.CHANGENICK, _defaultPacketHandler);
  }

  void initialize([VideoConstraints constraints]) {

    //if (!_requireAudio && !_requireVideo && !_requireDataChannel)
    //  throw new Exception("Must require either video, audio or data channel");

    VideoConstraints con = ?constraints ? constraints : _defaultGetUserMediaConstraints;
    if (!con.audio && !con.video && !_defaultPeerCreationConstraints.dataChannelEnabled)
      throw new Exception("Must require either video, audio or data channel");

    // If either is set, need to request permission for audio and/or video
    if ((con.audio || con.video) && _ms == null) {
      if (MediaStream.supported) {
        // TODO: Fix, this should take a map, but it's wrong in dartlang. https://code.google.com/p/dart/issues/detail?id=8061
        window.navigator.getUserMedia(audio: con.audio, video: con.video).then((LocalMediaStream stream) {
          _ms = stream;
          _pm.setLocalStream(stream);
          _sh.initialize();

          _setState(InitializationState.MEDIA_READY);
          _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(stream, null, true));
        });
      } else {
        _setState(InitializationState.NOT_READY);
        return;
      }
    } else {
      _sh.initialize();
    }


  }

  /**
   * Implements RtcClient setRequireAudio
   */
  ChannelClient setRequireAudio(bool b) {
    //_requireAudio = b;
    _defaultGetUserMediaConstraints.audio = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireVideo
   */
  ChannelClient setRequireVideo(bool b) {
    //_requireVideo = b;
    _defaultGetUserMediaConstraints.video = b;
    return this;
  }

  /**
   * Implements RtcClient setRequireDataChannel
   */
  ChannelClient setRequireDataChannel(bool b) {
    //_requireDataChannel = b;
    _defaultPeerCreationConstraints.dataChannelEnabled = b;
    _sh.setDataChannelsEnabled(b);
    return this;
  }

  /**
   * Implements RtcClient setChannel
   */
  ChannelClient setChannel(String c) {
    _channelId = c;
    _sh.channelId = c;
    return this;
  }

  /**
   * If true, Signalhandler will request peermanager to create peer connections
   * When ever a channel is joined.
   */
  ChannelClient setAutoCreatePeer(bool v) {
    _sh._createPeerOnJoin = v;
    return this;
  }

  ChannelClient setDefaultVideoConstraints(VideoConstraints vc) {
    _defaultGetUserMediaConstraints = vc;
    return this;
  }

  ChannelClient setDefaultPeerConstraints(PeerConstraints pc) {
    _defaultPeerCreationConstraints = pc;
    _pm.setPeerConstraints(pc);
    return this;
  }

  ChannelClient setDefaultStreamConstraints(StreamConstraints sc) {
    _defaultStreamConstraints = sc;
    _pm.setStreamConstraints(sc);
    return this;
  }

  /**
   * Requests to join a channel
   */
  void joinChannel(String name) {
    _sh.sendPacket(new ChannelJoinCommand.With(_myId, name));
  }

  /**
   * Change your id (nick)
   */
  void changeId(String newId) {
    _sh.sendPacket(new ChangeNickCommand.With(_myId, newId));
  }

  void _setState(InitializationState state) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasSubscribers)
      _initializedController.add(new InitializationStateEvent(state));
  }

  /**
   * Sets the userlimit on channel
   * The issuer has to be the channel owner
   */
  bool setChannelLimit(int l) {
    if (_channelId != null) {
      _sh.sendPacket(new SetChannelVarsCommand.With(_myId, _channelId, l));
      return true;
    }

    return false;
  }

  /**
   * Creates a peer connections and sets the creator as the host
   */
  void createPeerConnection(String id) {
    PeerWrapper p = _pm.createPeer();
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
    return _pm.findWrapper(id);
  }

  /**
   * Requests the server to transmit the message to all users in channel
   */
  void sendChannelMessage(String message) {
    _sh.send(PacketFactory.get(new ChannelMessage.With(_myId, _channelId, message)));
  }

  /**
   * Sends a message to a peer
   */
  void sendPeerUserMessage(String peerId, String message) {
    sendPeerPacket(peerId, new UserMessage.With(_myId, message));
  }

  /**
   * Sends a packet to peer
   */
  void sendPeerPacket(String peerId, Packet p) {
    PeerWrapper w = _pm.findWrapper(peerId);
    if (w is DataPeerWrapper) {
      DataPeerWrapper dpw = w as DataPeerWrapper;
      dpw.send(p);
    }
  }

  /**
   * Sends a blob to peer
   */
  void sendBlob(String peerId, Blob data) {
    throw new UnsupportedError("sendBlob is a work in progress");
  }

  /**
   * Sends an arraybuffer to peer
   */
  void sendArrayBuffer(String peerId, ArrayBuffer data) {
    throw new UnsupportedError("sendArrayBuffer is a work in progress");
  }

  /**
   * Sends an arraybufferview to peer
   */
  void sendArrayBufferView(String peerId, ArrayBufferView data) {
    throw new UnsupportedError("sendArrayBufferView is a work in progress");
  }

  /**
   * Request the server that users gets kicked out of channel
   */
  void disconnectUser() {
    if (isChannelOwner && _otherId != null) {
      _sh.send(PacketFactory.get(new RemoveUserCommand.With(_otherId, _channelId)));
    }
  }

  void _defaultPacketHandler(Packet p) {
    PeerWrapper pw = _pm.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  void _connectionSuccessPacketHandler(ConnectionSuccessPacket p) {
    _myId = p.id;
    if (_channelId != null)
      joinChannel(_channelId);
    _setState(InitializationState.REMOTE_READY);
  }

  void _channelPacketHandler(ChannelPacket p) {
    PeerWrapper pw = _pm.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));

    _setState(InitializationState.CHANNEL_READY);
  }

  void _joinPacketHandler(JoinPacket p) {
    _otherId = p.id;
    PeerWrapper pw = _pm.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  void _idPacketHandler(IdPacket p) {
    _otherId = p.id;
    PeerWrapper pw = _pm.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));
  }

  void _byePacketHandler(ByePacket p) {
    PeerWrapper pw = _pm.findWrapper(p.id);
    if (_packetController.hasSubscribers)
      _packetController.add(new PacketEvent(p, pw));

    if (_mediaStreamRemovedStreamController.hasSubscribers)
      _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
  }

  /**
   * Implements PeerDataEventListener onDateReceived
   */
  void onDataReceived(int buffered) {

  }

  /**
   * Implements PeerDataEventListener onChannelStateChanged
   */
  void onChannelStateChanged(DataPeerWrapper p, String state){

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

  void onPeerCreated(PeerWrapper pw) {
    if (pw is DataPeerWrapper) {
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
}