part of rtc_client;

abstract class Signaler {
  static const String SIGNALING_STATE_CLOSED = "closed";
  static const String SIGNALING_STATE_OPEN = "open";
  static const String SIGNALING_STATE_READY = "ready";

  Stream<SignalingStateEvent> get onSignalingStateChanged;
  Stream<ServerEvent> get onServerEvent;
  //Stream<ServerEvent> get onJoinChannel;
  //Stream<ServerEvent> get onParticipantJoin;
  //Stream<ServerEvent> get onParticipantId;
  //Stream<ServerEvent> get onParticipantStateChanged;
  //Stream<ServerEvent> get onParticipantLeft;
  void initialize();
  void send(String message);
  void close();

  // Need to be cleaned up
  void joinChannel(String id, String channelId);
  void changeId(String id, String newId);
  set channelId(String channelId);
  void setDataChannelsEnabled(bool value);
  bool get isChannelOwner;
  set createPeerOnJoin(bool v);
  bool setChannelLimit(int l);
}

