part of rtc_client;

class PeerStateChangedEvent extends RtcEvent {
  PeerConnection peerwrapper;
  String state;

  PeerStateChangedEvent(PeerConnection p, String s) {
    peerwrapper = p;
    state = s;
  }
}

class DataChannelStateChangedEvent extends RtcEvent {
  String state;
  PeerConnection peerwrapper;
  DataChannelStateChangedEvent(this.peerwrapper, this.state);
}

class IceGatheringStateChangedEvent extends RtcEvent {
  PeerConnection peerwrapper;
  String state;

  IceGatheringStateChangedEvent(PeerConnection p, String s) {
    peerwrapper = p;
    state = s;
  }
}