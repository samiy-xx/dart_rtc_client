part of rtc_client;

class BinaryChunkEvent extends RtcEvent {
  ArrayBuffer buffer;
  int signature;
  int sequence;
  int totalSequences;
  int bytes;
  int bytesLeft;

  BinaryChunkEvent(this.buffer, this.signature, this.sequence, this.totalSequences, this.bytes, this.bytesLeft);
}

class BinarySendCompleteEvent extends RtcEvent {
  int signature;
  int sequence;

  BinarySendCompleteEvent(this.signature, this.sequence);
}

class BinaryBufferComplete extends RtcEvent {
  ArrayBuffer buffer;

  BinaryBufferComplete(this.buffer);
}

