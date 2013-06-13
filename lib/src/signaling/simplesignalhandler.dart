part of rtc_client;

class SimpleSignalHandler extends PacketHandler implements Signaler, DataSourceConnectionEventListener {
  static final _logger = new Logger("dart_rtc_client.SimpleSignalHandler");

  StreamController<SignalingStateEvent> _signalingStateController;
  Stream<SignalingStateEvent> _onSignalingStateChanged;
  Stream<SignalingStateEvent> get onSignalingStateChanged => _onSignalingStateChanged;

  StreamController<ServerEvent> _serverEventController;
  Stream<ServerEvent> _onServerEvent;
  Stream<ServerEvent> get onServerEvent=> _onServerEvent;

  String _channelId;
  DataSource _ds;

  String get channelId => _channelId;
  set channelId(String value) => _channelId = value;

  SimpleSignalHandler(DataSource ds) : super() {
    _ds = ds;
    _ds.subscribe(this);

    _signalingStateController = new StreamController<SignalingStateEvent>();
    _onSignalingStateChanged = _signalingStateController.stream.asBroadcastStream();

    _serverEventController = new StreamController<ServerEvent>();
    _onServerEvent = _serverEventController.stream.asBroadcastStream();

    registerHandler(PACKET_TYPE_PING, handlePing);
    registerHandler(PACKET_TYPE_ICE, handleIce);
    registerHandler(PACKET_TYPE_DESC, handleDescription);
    registerHandler(PACKET_TYPE_BYE, handleBye);
    registerHandler(PACKET_TYPE_CONNECTED, handleConnectionSuccess);
    registerHandler(PACKET_TYPE_JOIN, handleJoin);
    registerHandler(PACKET_TYPE_ID, handleId);
    registerHandler(PACKET_TYPE_CHANGENICK, handleIdChange);
    registerHandler(PACKET_TYPE_CHANNEL, handleChannelInfo);
    registerHandler(PACKET_TYPE_CHANNELMESSAGE, _handleChannelMessage);
  }

  void initialize() {
    _ds.init();
  }

  void close() {
    _ds.send(PacketFactory.get(new ByePacket()));
    _ds.close();
  }

  void onCloseDataSource(String m) {
    if (_signalingStateController.hasListener)
      _signalingStateController.add(new SignalingStateEvent(Signaler.SIGNALING_STATE_CLOSED));
  }

  void onDataSourceError(String e) {
    // TODO: Do something?
    _logger.severe("Error $e");
  }

  void onOpenDataSource(String m) {
    if (_signalingStateController.hasListener)
      _signalingStateController.add(new SignalingStateEvent(Signaler.SIGNALING_STATE_OPEN));

    _logger.fine("WebSocket connection opened, sending HELO, ${_ds.readyState}");
    _ds.send(PacketFactory.get(new HeloPacket.With(_channelId, "")));
  }

  void onDataSourceMessage(String m) {
    Packet p;

    try {
      p = PacketFactory.getPacketFromString(m);
    } catch(e) {
      _logger.severe(e.toString());
    }

    if (p != null) {
      try {
        if (!executeHandler(p))
          _logger.warning("Packet ${p.packetType} has no handlers set");
      } on Exception catch(e) {
        _logger.severe(e.toString());
      } catch(e) {
        _logger.severe(e.toString());
      }
    }
  }

  void sendPacket(Packet p) {
    send(PacketFactory.get(p));
  }

  void send(String message) {
    _ds.send(message);
  }

  void changeId(String id, String newId) {
    sendPacket(new ChangeNickCommand.With(id, newId));
  }

  void joinChannel(String id, String channelId) {
    sendPacket(new ChannelJoinCommand.With(id, channelId));
  }

  void sendIceCandidate(PeerConnection pc, RtcIceCandidate candidate) {
    sendPacket(new IcePacket.With(candidate.candidate, candidate.sdpMid, candidate.sdpMLineIndex, pc.id));
  }

  void sendSessionDescription(PeerConnection pc, RtcSessionDescription sd) {
    sendPacket(new DescriptionPacket.With(sd.sdp, sd.type, pc.id, ""));
  }

  bool setChannelLimit(String id, String channelId, int l) {
    sendPacket(new SetChannelVarsCommand.With(id, channelId, l));
  }

  void _handleChannelMessage(ChannelMessage p) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerChannelMessageEvent(p.id, p.channelId, p.message));
  }

  void handleJoin(JoinPacket packet) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantJoinEvent(packet.id, packet.channelId));
  }

  void handleId(IdPacket id) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantIdEvent(id.id, id.channelId));
  }

  void handleBye(ByePacket p) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantLeftEvent(p.id));
  }

  void handleChannelInfo(ChannelPacket p) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerJoinEvent(p.channelId, p.owner, p.limit));
  }

  void handleIdChange(ChangeNickCommand c) {
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerParticipantStatusEvent(c.id, c.newId));
  }

  void handleConnectionSuccess(ConnectionSuccessPacket p) {
    if (_signalingStateController.hasListener)
      _signalingStateController.add(new SignalingReadyEvent(p.id, Signaler.SIGNALING_STATE_READY));
  }

  void handleIce(IcePacket p) {
    RtcIceCandidate candidate = new RtcIceCandidate({
      'candidate': p.candidate,
      'sdpMid': p.sdpMid,
      'sdpMLineIndex': p.sdpMLineIndex
    });
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerIceEvent(p.id, candidate));
  }

  void handleDescription(DescriptionPacket p) {
    RtcSessionDescription description = new RtcSessionDescription({
      'sdp':p.sdp,
      'type':p.type
    });
    if (_serverEventController.hasListener)
      _serverEventController.add(new ServerSessionDescriptionEvent(p.id, description));
  }

  void handlePing(PingPacket p) {
    _logger.fine("Received PING, answering with PONG");
    _ds.send(PacketFactory.get(new PongPacket()));
  }
}