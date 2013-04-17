part of rtc_client;

abstract class Signaler {
  static const String SIGNALING_STATE_CLOSED = "closed";
  static const String SIGNALING_STATE_OPEN = "open";

  Stream<SignalingStateEvent> get onSignalingStateChanged;
  Stream<ServerEvent> get onJoinChannel;
  Stream<ServerEvent> get onParticipantJoin;
  Stream<ServerEvent> get onParticipantId;
  Stream<ServerEvent> get onParticipantStateChanged;
  Stream<ServerEvent> get onParticipantLeft;
  void initialize();
  void send(String message);
}

