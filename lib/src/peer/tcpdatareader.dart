part of rtc_client;

class TCPDataReader extends BinaryDataReader {
  static final _logger = new Logger("dart_rtc_client.TCPDataReader");
  BinaryReadState _currentReadState = BinaryReadState.INIT_READ;
  int _packetType;
  int _leftToRead = 0;
  int _totalRead = 0;
  int _contentTotalLength;
  int _signature;
  int _currentChunkContentLength;
  ByteBuffer _latest;
  ByteData _latestView;
  int get leftToRead => _leftToRead;
  bool _fileAsBuffer = false;
  set fileAsBuffer(bool v) => _fileAsBuffer = v;
  TCPDataReader(PeerConnection peer) : super(peer) {

  }

  Future readChunkString(String s) {
    Completer c = new Completer();
    window.setImmediate(() {
      readChunk(BinaryData.bufferFromString(s));
      c.complete();
    });
    return c.future;
  }

  void readChunk(ByteBuffer buffer) {
    int i = 0;

    ByteData v = new ByteData.view(buffer);
    int chunkLength = v.lengthInBytes;

    while (i < chunkLength) {

      if (_currentReadState == BinaryReadState.INIT_READ) {
        _process_init_read(v.getUint8(i));
        i += SIZEOF8;
      }

      if (_currentReadState == BinaryReadState.READ_TYPE) {
        _process_read_type(v.getUint8(i));
        i += SIZEOF8;
      }

      if (_currentReadState == BinaryReadState.READ_LENGTH) {
        _process_read_length(v.getUint16(i));
        i += SIZEOF16;
      }

      if (_currentReadState == BinaryReadState.READ_TOTAL_LENGTH) {
        _process_read_total_length(v.getUint32(i));
        i += SIZEOF32;
      }

      if (_currentReadState == BinaryReadState.READ_SIGNATURE) {
        _process_read_signature(v.getUint32(i));
        i += SIZEOF32;
      }

      if (_currentReadState == BinaryReadState.READ_CONTENT) {
        _process_content_v2(buffer);
        i += buffer.lengthInBytes - SIZEOF_TCP_HEADER;
      }
    }
  }

  void _process_init_read(int b) {
    if (b == FULL_BYTE) {
      _currentReadState = BinaryReadState.READ_TYPE;
    }
  }

  void _process_read_type(int b) {
    _packetType = b;
    _currentReadState = BinaryReadState.READ_LENGTH;
  }

  void _process_read_length(int b) {
    _currentChunkContentLength = b;
    _leftToRead = b;
    _latest = new Uint8List(b).buffer;
    _latestView = new ByteData.view(_latest);
    _currentReadState = BinaryReadState.READ_TOTAL_LENGTH;
  }

  void _process_read_total_length(int b) {
    _contentTotalLength = b;
    _currentReadState = BinaryReadState.READ_SIGNATURE;
  }

  void _process_read_signature(int b) {
    _signature = b;
    _currentReadState = BinaryReadState.READ_CONTENT;
  }

  void _process_content_v2(ByteBuffer buffer) {
    _latest = buffer;
    _totalRead += buffer.lengthInBytes - SIZEOF_TCP_HEADER;
    _currentReadState = BinaryReadState.FINISH_READ;
    process_end();
  }

  void _process_content(int b, int index) {

    try {
      _latestView.setUint8(index, b);
    } catch (e) {
      _logger.severe("Error at index $index setting byte $b : exception $e");
    }

    _leftToRead -= SIZEOF8;
    _totalRead += SIZEOF8;

    if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      process_end();
    }
  }

  void process_end() {
    _signalReadChunk(_latest, _signature, _currentChunkContentLength, _contentTotalLength);
    if (_totalRead == _contentTotalLength)
      _processBuffer();

    _currentReadState = BinaryReadState.INIT_READ;
  }

  void _processBuffer() {
    _totalRead = 0;
    _contentTotalLength = 0;
    _totalRead = 0;
  }

  void _signalReadChunk(ByteBuffer buf, int signature, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadTcpChunk(_peer, buf, signature, bytes, bytesTotal);
    });
  }
}

