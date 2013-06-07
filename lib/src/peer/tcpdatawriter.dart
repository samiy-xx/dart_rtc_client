part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  const int MAX_FILE_BUFFER_SIZE = 1024 * 1024 * 20;

  TCPDataWriter(PeerConnection peer) : super(BINARY_PROTOCOL_TCP, peer) {
    _wrapToString = false;
    _writeChunkSize = 2048;
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    int signature = new Random().nextInt(100000000);
  }

  Future<int> sendFile(Blob file) {

  }

  Future<int> _send(ByteBuffer buffer, int packetType, int signature, int total) {
    int totalSequences = (buffer.lengthInBytes / _writeChunkSize).ceil();
    int leftToRead = buffer.lengthInBytes;
    int read = 0;
    while (read < buffer.lengthInBytes) {
      var toRead = leftToRead > _writeChunkSize ? _writeChunkSize : leftToRead;
      var toAdd = _sublist(buffer, read, toRead);
      var b = addTcpHeader(
          toAdd,
          packetType,
          signature,
          total
      );
      read += toRead;
      leftToRead -= toRead;
      write(b);
    }
  }

  void sendAck(ByteBuffer buffer) {

  }
}