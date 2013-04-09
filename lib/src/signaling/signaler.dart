part of rtc_client;

abstract class Signaler {

  Stream<Object> get onSignalingStateChanged;
  Stream<Object> get onJoin;
  Stream<Object> get onParticipant;
  Stream<Object> get onParticipantStateChanged;

  void initialize();
  void send(String message);
}

