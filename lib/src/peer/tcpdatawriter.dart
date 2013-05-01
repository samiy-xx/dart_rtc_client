part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  TCPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_TCP, wrapper) {

  }

  Future<int>  send(ByteBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    int signature = new Random().nextInt(100000000);
    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;
    int read = 0;
    while (read < buffer.lengthInBytes) {
      int toRead = buffer.lengthInBytes > _writeChunkSize ? _writeChunkSize : buffer.lengthInBytes;
      ByteBuffer b = addTcpHeader(
          //buffer.slice(read, read + toRead),
          new Uint8List.view(buffer, read, read + toRead).buffer,
          packetType,
          signature,
          buffer.lengthInBytes
      );
      _send(b);
    }
    return completer.future;
  }
}