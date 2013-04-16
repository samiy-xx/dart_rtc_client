part of rtc_client;


class SignalingOpenEvent extends RtcEvent {
  String message;
  
  SignalingOpenEvent(String m) {
    message = m;
  }
}

class SignalingCloseEvent extends RtcEvent {
  String message;
  
  SignalingCloseEvent(String m) {
    message = m;
  }
}

class SignalingStateEvent extends RtcEvent {
  String state;
  SignalingStateEvent(this.state);
}

class SignalingErrorEvent extends RtcEvent {
  String message;
  
  SignalingErrorEvent(String m) {
    message = m;
  }
}



