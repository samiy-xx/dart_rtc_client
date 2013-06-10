part of rtc_client;

class ArrayBufferDataReader extends BinaryDataReader {
  static final _logger = new Logger("dart_rtc_client.ArrayBufferDataReader");

  ArrayBufferDataReader(PeerConnection peer) : super(peer) {
    _logger.finest("ArrayBufferDataReader created");
  }

  void readChunk(ByteBuffer buffer) {
    _signalReadChunk(buffer, 0, buffer.lengthInBytes, buffer.lengthInBytes);
  }

  void _signalReadChunk(ByteBuffer buf, int signature, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadTcpChunk(_peer, buf, signature, bytes, bytesTotal);
    });
  }

}