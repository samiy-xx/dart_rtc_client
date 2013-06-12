part of rtc_client;

class ByteWriter extends BinaryDataWriter {
  static final _logger = new Logger("dart_rtc_client.TCPDataWriter");
  List<ByteBuffer> _toSend;

  ByteWriter(PeerConnection peer) : super(BINARY_PROTOCOL_TCP, peer) {
    _wrapToString = false;
    _writeChunkSize = 4096 * 2;
    _toSend = new List<ByteBuffer>();
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    int signature = new Random().nextInt(100000000);
    return _send(buffer, packetType, signature, buffer.lengthInBytes);
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