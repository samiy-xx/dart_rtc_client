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
  void onPeerPacket(PeerPacket p);
  void onPeerString(String s);
  void onPeerBuffer(ArrayBuffer b);
  void onPeerReadChunk(ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesLeft);

  void onPeerSendSuccess(int signature, int sequence);
}

/**
 * Interface for sent binary data events
 */
abstract class BinaryDataSentEventListener extends BinaryDataEventListener {
  void onWriteChunk(int signature, int sequence, int totalSequences, int bytes, int bytesLeft);
}

abstract class BinaryBlobReadEventListener extends BinaryDataEventListener {
  void onProgress();
  void onLoadDone(ArrayBuffer b);
}