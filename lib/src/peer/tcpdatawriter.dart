part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  static const int MAX_FILE_BUFFER_SIZE = 1024 * 1024 * 5;
  static final _logger = new Logger("dart_rtc_client.TCPDataWriter");
  List<ByteBuffer> _toSend;

  TCPDataWriter(PeerConnection peer) : super(BINARY_PROTOCOL_TCP, peer) {
    _wrapToString = false;
    _writeChunkSize = 4096 * 2;
    _toSend = new List<ByteBuffer>();
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    int signature = new Random().nextInt(100000000);
    return _send(buffer, packetType, signature, buffer.lengthInBytes);
  }

  Future<int> sendFile(Blob b) {
    Completer<int> c = new Completer<int>();

    int left_to_send = b.size;
    int read = 0;


    new Timer.periodic(const Duration(milliseconds: 1), (Timer t) {
      if (buffered > 0)
        return;

      int size_to_send = left_to_send > _writeChunkSize ? _writeChunkSize : left_to_send;
      Blob toSend = b.slice(read, read + size_to_send);

      read += size_to_send;
      left_to_send -= size_to_send;
      _signalWriteChunk(0, 0, 0, toSend.size);
      writeBlob(toSend);
      _signalWroteChunk(0, 0, 0, toSend.size);
      if (left_to_send == 0) {
        t.cancel();
        c.complete(1);
      }
    });

    return c.future;
  }

  Future<int> _sendFile(Blob file) {
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

    _logger.finest("Buffering $leftToRead bytes for send");
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
      _toSend.add(b);
      //write(b);
    }
    _logger.finest("Buffered $leftToRead bytes for send");
    _sendList(completer);
    //completer.complete(1);

    return completer.future;
  }

  void _sendList(Completer c) {
    new Timer.periodic(const Duration(milliseconds: 5), (Timer t) {
      if (_toSend.length == 0) {
        t.cancel();
        c.complete(1);
        _logger.finest("All sent");
      } else {
        write(_toSend.removeAt(0));
      }
    });
  }
  void sendAck(ByteBuffer buffer) {

  }

  void _signalWriteChunk(int signature, int sequence, int totalSequences, int bytes) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWriteChunk(_peer, signature, sequence, totalSequences, bytes);
      });
    });
  }

  void _signalWroteChunk(int signature, int sequence, int totalSequences, int bytes) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWroteChunk(_peer, signature, sequence, totalSequences, bytes);
      });
    });
  }
}