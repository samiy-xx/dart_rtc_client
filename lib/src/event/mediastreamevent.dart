part of rtc_client;

class MediaStreamAvailableEvent extends RtcEvent {
  MediaStream stream;
  PeerConnection peerWrapper;
  bool isLocal = false;

  MediaStreamAvailableEvent(MediaStream m, PeerConnection p, [bool local = true]) {
    stream = m;
    peerWrapper = p;
    isLocal = local;
  }
}

class MediaStreamRemovedEvent extends RtcEvent {
  PeerConnection pw;

  MediaStreamRemovedEvent(PeerConnection p) {
    pw = p;
  }
}