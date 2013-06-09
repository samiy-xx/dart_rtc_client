part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  const int MAX_FILE_BUFFER_SIZE = 1024 * 1024 * 20;
  static final _logger = new Logger("dart_rtc_client.TCPDataWriter");

  TCPDataWriter(PeerConnection peer) : super(BINARY_PROTOCOL_TCP, peer) {
    _wrapToString = false;
    _writeChunkSize = 2048;
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    int signature = new Random().nextInt(100000000);
    return _send(buffer, packetType, signature, buffer.lengthInBytes);
  }

  Future<int> sendFile(Blob file) {
    Completer<int> completer = new Completer<int>();
    FileReader reader = new FileReader();
    int totalSequences = _getSequenceTotal(file.size);
    int read = 0;
    int leftToRead = file.size;
    int signature = new Random().nextInt(100000000);
    int toRead = file.size > MAX_FILE_BUFFER_SIZE ? MAX_FILE_BUFFER_SIZE : file.size;
    reader.readAsArrayBuffer(file.slice(read, read + toRead));
    reader.onLoadEnd.listen((ProgressEvent e) {
      _send(reader.result, BINARY_TYPE_FILE, signature, file.size).then((int i) {
        read += toRead;
        leftToRead -= toRead;
        if (read < file.size) {
          toRead = leftToRead > MAX_FILE_BUFFER_SIZE ? MAX_FILE_BUFFER_SIZE : file.size;
          reader.readAsArrayBuffer(file.slice(read, read + toRead));
        } else {
          completer.complete(1);
        }
      });
    });
    return completer.future;
  }

  Future<int> _send(ByteBuffer buffer, int packetType, int signature, int total) {
    Completer<int> completer = new Completer<int>();
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
    return completer.future;
  }

  void sendAck(ByteBuffer buffer) {

  }
}