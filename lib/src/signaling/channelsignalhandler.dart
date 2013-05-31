part of rtc_client;

class ChannelSignalHandler extends SignalHandler{
  static final _logger = new Logger("dart_rtc_client.ChannelSignalHandler");
  /* id for the channel */
  String _channelId;
  bool _isChannelOwner = false;
  bool get isChannelOwner => _isChannelOwner;

  String get channelId => _channelId;
  set channelId(String value) => _channelId = value;

  ChannelSignalHandler(DataSource ds) : super(ds) {
    registerHandler(PACKET_TYPE_CHANNEL, handleChannelInfo);
  }

  /**
   * Callback for websocket onopen
   */
  void onOpenDataSource(String e) {
    super.onOpenDataSource(e);
    _logger.fine("WebSocket connection opened, sending HELO, ${_dataSource.readyState}");
    _dataSource.send(PacketFactory.get(new HeloPacket.With(_channelId, "")));
  }

  void handleChannelInfo(ChannelPacket p) {
    _logger.info("ChannelPacket owner=${p.owner}");
    _isChannelOwner = p.owner;
  }

  void handleJoin(JoinPacket packet) {
    super.handleJoin(packet);

    // If it's our id, then we received our channel id
    if (packet.id == _id)
      _channelId = packet.channelId;

    if (createPeerOnJoin) {
      PeerConnection p = _peerManager.findWrapper(packet.id);
      if (p != null)
        p.channel = packet.channelId;
    }
  }

  void handleId(IdPacket id) {
    super.handleId(id);

    if (createPeerOnJoin) {
      PeerConnection p = _peerManager.findWrapper(id.id);
      if (p != null)
        p.channel = id.channelId;
    }

  }
}
