part of rtc_client;

abstract class Signaler {
  const String SIGNALING_STATE_CLOSED = "closed";
  const String SIGNALING_STATE_OPEN = "open";
  
  Stream<SignalingStateEvent> get onSignalingStateChanged;
  Stream<Object> get onJoin;
  Stream<Object> get onParticipant;
  Stream<Object> get onParticipantStateChanged;

  void initialize();
  void send(String message);
}

