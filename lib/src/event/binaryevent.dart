part of rtc_client;

class BinaryChunkEvent extends RtcEvent {
  PeerWrapper peer;
  ByteBuffer buffer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;
  int bytesTotal;

  BinaryChunkEvent(this.peer, this.buffer, this.signature, this.sequence, this.totalSequences, this.bytes, this.bytesTotal);
}

class BinaryChunkWriteEvent extends RtcEvent {
  PeerWrapper peer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;

  BinaryChunkWriteEvent(this.peer, this.signature, this.sequence, this.totalSequences, this.bytes);
}

class BinaryChunkWroteEvent extends RtcEvent {
  PeerWrapper peer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;

  BinaryChunkWroteEvent(this.peer, this.signature, this.sequence, this.totalSequences, this.bytes);
}

class BinarySendCompleteEvent extends RtcEvent {
  int signature;
  int sequence;

  BinarySendCompleteEvent(this.signature, this.sequence);
}

class BinaryBufferCompleteEvent extends RtcEvent {
  PeerWrapper peer;
  ByteBuffer buffer;

  BinaryBufferCompleteEvent(this.peer, this.buffer);
}

class BinaryFileCompleteEvent extends RtcEvent {
  PeerWrapper peer;
  Blob blob;

  BinaryFileCompleteEvent(this.peer, this.blob);
}

