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
  void onPacket(Packet p);
  void onString(String s);
  void onBuffer(ArrayBuffer b);
  void onReadChunk(int signature, int sequence, int totalSequences, int bytes, int bytesLeft);
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