part of rtc_client;

/**
 * Interface for Binary data events
 */
abstract class BinaryDataEventListener {

}

/**
 * Interface for received binary data events
 */
abstract class BinaryDataReceivedEventListener extends BinaryDataEventListener {
  //void onPeerPacket(PeerWrapper pw, PeerPacket p);
  void onPeerString(PeerConnection pc, String s);
  void onPeerBuffer(PeerConnection pc, ByteBuffer b, int binaryType);
  void onPeerFile(PeerConnection pc, Blob b);
  void onPeerBlobChunk(PeerConnection pc, Blob b);
  void onPeerReadUdpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal);
  void onPeerReadTcpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int bytes, int bytesTotal);
  void onPeerSendSuccess(int signature, int sequence);
}

/**
 * Interface for sent binary data events
 */
abstract class BinaryDataSentEventListener extends BinaryDataEventListener {
  /**
   * Fires when data is written to the channel
   */
  void onWriteChunk(PeerConnection pc, int signature, int sequence, int totalSequences, int bytes);

  /**
   * Fires when data is arrived to opposite end of channel
   */
  void onWroteChunk(PeerConnection pc, int signature, int sequence, int totalSequences, int bytes);
}

abstract class BinaryBlobReadEventListener extends BinaryDataEventListener {
  void onProgress();
  void onLoadDone(ByteBuffer b);
}