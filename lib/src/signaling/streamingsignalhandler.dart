part of rtc_client;

class StreamingSignalHandler extends SignalHandler {
  String other = null;

  StreamingSignalHandler(DataSource ds) : super(ds) {
    registerHandler(PACKET_TYPE_JOIN, onJoinChannel);
    registerHandler(PACKET_TYPE_ID, onIdExistingChannelUser);
  }

  void onJoinChannel(JoinPacket p) {
    if (channelId != "")
      print("got channel id channelId");

    if (p.id != id)
      other = p.id;
  }

  void onIdExistingChannelUser(IdPacket p) {
    if (p.id != id)
      other = p.id;
  }

  void sendMessage(String id, String message) {
    send(PacketFactory.get(new UserMessage.With(other, message)));
  }

  void handleJoin(JoinPacket join) {
    super.handleJoin(join);
    PeerWrapper pw = peerManager.findWrapper(join.id);
    MediaStream ms = peerManager.getLocalStream();
    if (ms != null)
      pw.addStream(ms);
  }

  void handleId(IdPacket id) {
    super.handleId(id);
    if (!id.id.isEmpty) {
      PeerWrapper pw = peerManager.findWrapper(id.id);
      MediaStream ms = peerManager.getLocalStream();
      if (ms != null)
        pw.addStream(ms);
    }
  }
}

