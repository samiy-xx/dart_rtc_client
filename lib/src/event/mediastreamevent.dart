part of rtc_client;

class MediaStreamAvailableEvent extends RtcEvent {
  MediaStream stream;
  PeerWrapper peerWrapper;
  bool isLocal = false;
  
  MediaStreamAvailableEvent(MediaStream m, PeerWrapper p, [bool local]) {
    stream = m;
    peerWrapper = p;
    
    if (?local)
      isLocal = local;
  }
}

class MediaStreamRemovedEvent extends RtcEvent {
  PeerWrapper pw;
  
  MediaStreamRemovedEvent(PeerWrapper p) {
    pw = p;
  }
}