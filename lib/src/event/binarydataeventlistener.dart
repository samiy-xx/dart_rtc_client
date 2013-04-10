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
  void onPeerString(PeerWrapper pw, String s);
  void onPeerBuffer(PeerWrapper pw, ArrayBuffer b);
  void onPeerFile(PeerWrapper pw, Blob b);
  void onPeerReadChunk(PeerWrapper pw, ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal);

  void onPeerSendSuccess(int signature, int sequence);
}

/**
 * Interface for sent binary data events
 */
abstract class BinaryDataSentEventListener extends BinaryDataEventListener {
  void onWriteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes);
  void onWroteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes);
}

abstract class BinaryBlobReadEventListener extends BinaryDataEventListener {
  void onProgress();
  void onLoadDone(ArrayBuffer b);
}