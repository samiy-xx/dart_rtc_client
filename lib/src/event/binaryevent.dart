part of rtc_client;

class BinaryChunkEvent extends RtcEvent {
  PeerWrapper peer;
  ArrayBuffer buffer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;
  int bytesTotal;

  BinaryChunkEvent(this.peer, this.buffer, this.signature, this.sequence, this.totalSequences, this.bytes, this.bytesTotal);
}

class BinarySendCompleteEvent extends RtcEvent {
  int signature;
  int sequence;

  BinarySendCompleteEvent(this.signature, this.sequence);
}

class BinaryBufferCompleteEvent extends RtcEvent {
  PeerWrapper peer;
  ArrayBuffer buffer;

  BinaryBufferCompleteEvent(this.peer, this.buffer);
}

class BinaryPeerPacketEvent extends RtcEvent {
  PeerWrapper peer;
  PeerPacket peerPacket;

  BinaryPeerPacketEvent(this.peer, this.peerPacket);
}

