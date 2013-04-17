part of rtc_client;

/**
 * SignalHandler
 */
class SignalHandler extends PacketHandler implements Signaler, PeerPacketEventListener, DataSourceConnectionEventListener {
  Logger _log = new Logger();

  DataSource _dataSource;
  PeerManager _peerManager;
  String _id;
  String _channelId;
  bool _dataChannelsEnabled = false;
  bool _createPeerOnJoin = true;
  bool get createPeerOnJoin => _createPeerOnJoin;

  String get channelId => _channelId;
  set channelId(String value) => _channelId = value;
  set createPeerOnJoin(bool v) => _createPeerOnJoin = v;
  PeerManager get peerManager => getPeerManager();
  DataSource get dataSource => _dataSource;
  set peerManager(PeerManager p) => setPeerManager(p);
  set dataChannelsEnabled(bool value) => setDataChannelsEnabled(value);
  String get id => _id;
  bool _isChannelOwner = false;
  bool get isChannelOwner => _isChannelOwner;

  StreamController<SignalingStateEvent> _signalingStateController;
  Stream<SignalingStateEvent> _onSignalingStateChanged;
  Stream<SignalingStateEvent> get onSignalingStateChanged => _onSignalingStateChanged;

  StreamController<ServerEvent> _serverEventController;
  Stream<ServerEvent> _onServerEvent;
  Stream<ServerEvent> get onServerEvent=> _onServerEvent;

  SignalHandler(DataSource ds) : super() {
    _dataSource = ds;
    _dataSource.subscribe(this);

    _peerManager = new PeerManager();
    _peerManager.subscribe(this);

    registerHandler(PACKET_TYPE_PING, handlePing);
    registerHandler(PACKET_TYPE_ICE, handleIce);
    registerHandler(PACKET_TYPE_DESC, handleDescription);
    registerHandler(PACKET_TYPE_BYE, handleBye);
    registerHandler(PACKET_TYPE_CONNECTED, handleConnectionSuccess);
    registerHandler(PACKET_TYPE_JOIN, handleJoin);
    registerHandler(PACKET_TYPE_ID, handleId);
    registerHandler(PACKET_TYPE_CHANGENICK, handleIdChange);
    registerHandler(PACKET_TYPE_CHANNEL, handleChannelInfo);

    _signalingStateController = new StreamController<SignalingStateEvent>();
    _onSignalingStateChanged = _signalingStateController.stream.asBroadcastStream();

    _serverEventController = new StreamController<ServerEvent>();
    _onServerEvent = _serverEventController.stream.asBroadcastStream();
  }

  /**
   * Sets data channels enabled
   * calls the same method in peer manager
   */
  void setDataChannelsEnabled(bool value) {
    _dataChannelsEnabled = value;
    _peerManager.dataChannelsEnabled = value;
  }

  /**
   * Initializes the connection to the web socket server
   * If no host parameter is given, uses the default one from lib
   * @param optional parameter host
   */
  void initialize() {
    if (_peerManager == null)
      throw new Exception("PeerManager is null");

    _dataSource.init();
  }

  /**
   * Sets the PeerManager
   */
  void setPeerManager(PeerManager p) {
    if (p == null)
      throw new Exception("PeerManager is null");

    _peerManager = p;
  }
  //TODO : Remove? Peermanager is singleton instance
  /**
   * Returns the peer manager
   * @return PeerManager
   */
  PeerManager getPeerManager() {
    return _peerManager;
  }

  /**
   * Creates a peer wrapper instance
   * @return PeerWrapper
   */
  PeerWrapper createPeerWrapper() {
    return _peerManager.createPeer();
  }

  /**
   * Implements DataSourceConnectionEventListener onOpen
   */
  void onOpenDataSource(String m) {
    if (_signalingStateController.hasListener)
      _signalingStateController.add(new SignalingStateEvent(Signaler.SIGNALING_STATE_OPEN));

    _log.Debug("(signalhandler.dart) WebSocket connection opened, sending HELO, ${_dataSource.readyState}");
    _dataSource.send(PacketFactory.get(new HeloPacket.With(_channelId, "")));
  }

  /**
   * Implements DataSourceConnectionEventListener onClose
   */
  void onCloseDataSource(String m) {
    if (_signalingStateController.hasListener)
      _signalingStateController.add(new SignalingStateEvent(Signaler.SIGNALING_STATE_CLOSED));
    //_log.Debug("Connection closed ${m}");
  }

  /**
   * Implements DataSourceConnectionEventListener onError
   */
  void onDataSourceError(String e) {
    _log.Error("Error $e");
  }

  /**
   * Implements DataSourceConnectionEventListener onMessage
   */
  void onDataSourceMessage(String m) {
    // Get the packet via PacketFactory
    Packet p;

    try {
      p = PacketFactory.getPacketFromString(m);
    } catch(e) {
      _log.Error(e.toString());
    }

    if (p != null) {
      try {
        if (!executeHandler(p))
          _log.Warning("Packet ${p.packetType} has no handlers set");
      } on Exception catch(e) {
        _log.Error(e.toString());
      } catch(e) {
        _log.Error(e.toString());
      }
    }
  }

  /**
   * Send string data trough datasource
   */
  void send(String p) {
    _dataSource.send(p);
  }

  /**
   * Sends a packet trough datasource
   */
  void sendPacket(Packet p) {
    send(PacketFactory.get(p));
  }

  // TODO: Need to be able to send arraybuffer to server
  /**
   * Sends an arraybuffer trough the datasource
   */
  void sendArrayBuffer(ArrayBuffer b) {
    throw new UnimplementedError("Sending ArrayBuffer is not implemented");
  }

  /**
   * Implements PeerPacketEventListener onPacketToSend
   */
  void onPacketToSend(String p) {
    send(p);
  }

  /**
   * Handle join packet
   */
  void handleJoin(JoinPacket packet) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantJoinEvent(packet.id, packet.channelId));
    try {
      _log.Debug("(signalhandler.dart) JoinPacket channel ${packet.channelId} user ${packet.id}");
      if (_createPeerOnJoin) {
        PeerWrapper p = createPeerWrapper();
        p.id = packet.id;
        p.channel = packet.channelId;
        p.setAsHost(true);
      }
    } catch (e) {
      _log.Error("(signalhandler.dart) Error handleJoin $e");
    }
  }

  /**
   * Handle id packet
   */
  void handleId(IdPacket id) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantJoinEvent(id.id, id.channelId));
    _log.Debug("(signalhandler.dart) ID packet: channel ${id.channelId} user ${id.id}");
    if (id.id != null && !id.id.isEmpty) {
      if (_createPeerOnJoin) {
        PeerWrapper p = createPeerWrapper();
        p.id = id.id;
        p.channel = id.channelId;
      }
    }
  }

  /**
   * Handles Bye packet
   */
  void handleBye(ByePacket p) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantLeftEvent(p.id));

    _log.Debug("(signalhandler.dart) Received BYE from ${p.id}");
    PeerWrapper peer = _peerManager.findWrapper(p.id);
    if (peer != null) {
      _log.Debug("(signalhandler.dart) Closing peer ${peer.id}");
      peer.close();
    }
  }

  void handleChannelInfo(ChannelPacket p) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerJoinEvent(p.channelId, p.owner, p.limit));

    _log.Info("(signalhandler.dart) ChannelPacket owner=${p.owner}");
    _isChannelOwner = p.owner;
  }

  void handleIdChange(ChangeNickCommand c) {
    _log.Debug("(signalhandler.dart) CHANGEID packet: user ${c.id} to ${c.newId}");
    if (c.id == _id) {
      // t's me
      _id = c.id;
    } else {
      PeerWrapper pw = _peerManager.findWrapper(c.id);
      if (pw != null)
        pw.id = c.newId;
    }
  }
  /**
   * handle connection success
   */
  void handleConnectionSuccess(ConnectionSuccessPacket p) {
    _log.Debug("(signalhandler.dart) Connection successfull user ${p.id}");
    _id = p.id;
  }

  /**
   * Handles ice
   */
  void handleIce(IcePacket p) {
    RtcIceCandidate candidate = new RtcIceCandidate({
      'candidate': p.candidate,
      'sdpMid': p.sdpMid,
      'sdpMLineIndex': p.sdpMLineIndex
    });

    PeerWrapper peer = _peerManager.findWrapper(p.id);
    if (peer != null) {
      peer.addRemoteIceCandidate(candidate);
    }
  }

  /**
   * Handles sdp description
   */
  void handleDescription(DescriptionPacket p) {
    _log.Debug("(signalhandler.dart) RECV: DescriptionPacket channel ${p.channelId} user ${p.id}");

    RtcSessionDescription t = new RtcSessionDescription({
      'sdp':p.sdp,
      'type':p.type
    });
    PeerWrapper peer = _peerManager.findWrapper(p.id);

    if (peer == null) {
      _log.Debug("(signalhandler.dart) Peer not found with id ${p.id}. Creating...");
      peer = createPeerWrapper();
      peer.id = p.id;
    }

    _log.Debug("(signalhandler.dart) Setting remote description to peer");
    peer.setRemoteSessionDescription(t);
  }

  /**
   * Handles ping from server, responds with pong
   */
  void handlePing(PingPacket p) {
    _log.Debug("(signalhandler.dart) Received PING, answering with PONG");
    _dataSource.send(PacketFactory.get(new PongPacket()));
  }



  /**
   * Close the Web socket connection to the signaling server
   */
  void close() {
    _dataSource.send(PacketFactory.get(new ByePacket.With(_id)));
    _dataSource.close();
  }
}
