part of rtc_client;

class PacketEvent extends RtcEvent {
  Packet packet;
  PeerConnection peerwrapper;
  String type;

  PacketEvent(Packet p, PeerConnection pw) {
    packet = p;
    peerwrapper = pw;
    type = p.packetType;
  }
}

