part of rtc_client;

class ChannelSignalHandler extends SignalHandler{
  /* id for the channel */
  String _channelId;
  bool _isChannelOwner = false;
  bool get isChannelOwner => _isChannelOwner;
  
  String get channelId => _channelId;
  set channelId(String value) => _channelId = value;
  
  ChannelSignalHandler(DataSource ds) : super(ds) {
    registerHandler(PacketType.CHANNEL, handleChannelInfo);
  }
  
  /**
   * Callback for websocket onopen
   */
  void onOpenDataSource(String e) {
    _log.Debug("(channelsignalhandler.dart) WebSocket connection opened, sending HELO, ${_dataSource.readyState}");
    _dataSource.send(PacketFactory.get(new HeloPacket.With(_channelId, "")));
  }
  
  void handleChannelInfo(ChannelPacket p) {
    _log.Info("(channelsignalhandler.dart) ChannelPacket owner=${p.owner}");
    _isChannelOwner = p.owner;
  }
  
  void handleJoin(JoinPacket packet) {
    super.handleJoin(packet);
    
    // If it's our id, then we received our channel id
    if (packet.id == _id)
      _channelId = packet.channelId;
    
    if (createPeerOnJoin) {
      PeerWrapper p = _peerManager.findWrapper(packet.id);
      if (p != null)
        p.channel = packet.channelId;
    }
  }
  
  void handleId(IdPacket id) {
    super.handleId(id);
    
    if (createPeerOnJoin) {
      PeerWrapper p = _peerManager.findWrapper(id.id);
      if (p != null)
        p.channel = id.channelId;
    }
    
  }
}
