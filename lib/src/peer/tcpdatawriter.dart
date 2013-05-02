part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  TCPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_TCP, wrapper) {

  }

  Future<int>  send(ByteBuffer buffer, int packetType) {
    Completer completer = new Completer();
    int signature = new Random().nextInt(100000000);
    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    while (read < buffer.lengthInBytes) {
      int toRead = leftToRead > _writeChunkSize ? _writeChunkSize : leftToRead;
      ByteBuffer toAdd = new Uint8List.fromList(new Uint8List.view(buffer).sublist(read, read+toRead));
      ByteBuffer b = addTcpHeader(
          toAdd,
          packetType,
          signature,
          buffer.lengthInBytes
      );
      write(b);
      read += toRead;
      leftToRead -= toRead;
    }
    completer.complete(1);
    return completer.future;
  }
}