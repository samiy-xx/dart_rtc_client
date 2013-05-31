part of rtc_client;

abstract class Signaler {
  static const String SIGNALING_STATE_CLOSED = "closed";
  static const String SIGNALING_STATE_OPEN = "open";
  static const String SIGNALING_STATE_READY = "ready";

  Stream<SignalingStateEvent> get onSignalingStateChanged;
  Stream<ServerEvent> get onServerEvent;

  void initialize();
  void send(String message);
  void close();

  void sendSessionDescription(PeerConnection pc, RtcSessionDescription sd);
  void sendIceCandidate(PeerConnection pc, RtcIceCandidate candidate);
  void joinChannel(String id, String channelId);
  void changeId(String id, String newId);
  set channelId(String channelId);
  //void setDataChannelsEnabled(bool value);
  bool get isChannelOwner;
  set createPeerOnJoin(bool v);
  bool setChannelLimit(String id, String channelId, int l);
}

