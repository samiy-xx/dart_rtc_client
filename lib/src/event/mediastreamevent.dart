part of rtc_client;

class MediaStreamAvailableEvent extends RtcEvent {
  MediaStream stream;
  PeerConnection peerWrapper;
  bool isLocal = false;

  MediaStreamAvailableEvent(MediaStream m, PeerConnection p, [bool local]) {
    stream = m;
    peerWrapper = p;

    if (?local)
      isLocal = local;
  }
}

class MediaStreamRemovedEvent extends RtcEvent {
  PeerConnection pw;

  MediaStreamRemovedEvent(PeerConnection p) {
    pw = p;
  }
}