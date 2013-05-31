part of rtc_client;

class BinaryChunkEvent extends RtcEvent {

  PeerConnection peer;
  ByteBuffer buffer;
  int binary_protocol;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;
  int bytesTotal;

  BinaryChunkEvent(this.peer, this.buffer, this.signature, this.sequence, this.totalSequences, this.bytes, this.bytesTotal, this.binary_protocol);
}

class BinaryChunkWriteEvent extends RtcEvent {
  PeerConnection peer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;

  BinaryChunkWriteEvent(this.peer, this.signature, this.sequence, this.totalSequences, this.bytes);
}

class BinaryChunkWroteEvent extends RtcEvent {
  PeerConnection peer;
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
  PeerConnection peer;
  ByteBuffer buffer;
  int binaryType;

  BinaryBufferCompleteEvent(this.peer, this.buffer, this.binaryType);
}

class BinaryFileCompleteEvent extends RtcEvent {
  PeerConnection peer;
  Blob blob;

  BinaryFileCompleteEvent(this.peer, this.blob);
}
