part of rtc_client;

class InitializationState {
  static final InitializationState NOT_READY = const InitializationState(0);
  static final InitializationState MEDIA_READY = const InitializationState(1);
  static final InitializationState LOCAL_READY = const InitializationState(2);
  static final InitializationState REMOTE_READY = const InitializationState(3);
  static final InitializationState CHANNEL_READY = const InitializationState(4);
  final int _state;
  
  const InitializationState(int state) : _state = state;
}

class InitializationStateEvent extends RtcEvent {
  
  InitializationState state;
  
  InitializationStateEvent(InitializationState s) {
    state = s;
  }
}

class ChannelInitializationStateEvent extends InitializationStateEvent {
  
  InitializationState state;
  String channel;
  bool owner;
  
  ChannelInitializationStateEvent(InitializationState s, String c, bool o) : super(s) {
    channel = c;
    owner = o;
  }
}



