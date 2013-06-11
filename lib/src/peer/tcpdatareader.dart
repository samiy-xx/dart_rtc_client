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
  List<Blob> _blobs;
  List<ByteBuffer> _buffers;
  int get leftToRead => _leftToRead;
  bool _fileAsBuffer = false;
  set fileAsBuffer(bool v) => _fileAsBuffer = v;

  TCPDataReader(PeerConnection peer) : super(peer) {
    _logger.finest("TCPDataReader created");
    _buffers = new List<ByteBuffer>();
    _blobs = new List<Blob>();
  }

  void readBlob(Blob b) {
    _signalReadBlobChunk(b);
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
    if (!BinaryData.isValidTcp(buffer)) {
      _process_custom(buffer);
      return;
    }
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

      //if (_currentReadState == BinaryReadState.READ_CUSTOM) {
      //  _process_custom(buffer);
      //  i += buffer.lengthInBytes;
      //}
    }
  }

  void _process_init_read(int b) {
    if (b == FULL_BYTE) {
      _currentReadState = BinaryReadState.READ_TYPE;
    } else {
      _currentReadState = BinaryReadState.READ_CUSTOM;
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
    //_currentReadState = BinaryReadState.FINISH_READ;
    _buffers.add(buffer);
    process_end();
  }


  void process_end() {

    _signalReadChunk(_latest, _signature, _currentChunkContentLength, _contentTotalLength);
    if (_totalRead == _contentTotalLength)
      _processBuffer();

    _currentReadState = BinaryReadState.INIT_READ;
  }

  void _processBuffer() {
    _logger.finest("_processBuffer");

    var type = _packetType;
    _buildCompleteBuffer(_contentTotalLength).then((ByteBuffer b) {
      _doSignalingBasedOnBufferType(b, type);
    });
    _totalRead = 0;
    _contentTotalLength = 0;
    _totalRead = 0;
  }

  void _process_custom(ByteBuffer b) {
    _signalReadBuffer(b, BINARY_TYPE_TEST);
    //_currentReadState = BinaryReadState.INIT_READ;
  }

  Future<ByteBuffer> _buildCompleteBuffer(int size) {
    Completer<ByteBuffer> completer = new Completer<ByteBuffer>();
    _logger.finest("CREATE BUFFER OF SIZE $size");
    window.setImmediate(() {

      ByteBuffer complete = new Uint8List(size).buffer;
      ByteData completeView = new ByteData.view(complete);
      int k = 0;
      for (int i = 0; i < _buffers.length; i++) {
        ByteBuffer part = _buffers[i];
        ByteData partView = new ByteData.view(part, SIZEOF_TCP_HEADER);
        for (int j = 0; j < part.lengthInBytes - SIZEOF_TCP_HEADER; j++) {
          try {
            completeView.setUint8(k, partView.getUint8(j));
          } on RangeError catch(e) {
            _logger.severe("Attempted to insert $k $j");
          }
          k++;
        }
      }
      _buffers.clear();
      completer.complete(complete);
    });
    return completer.future;
  }

  void _doSignalingBasedOnBufferType(ByteBuffer buffer, int type) {

    switch (type) {
        case BINARY_TYPE_STRING:
          _logger.finest("Signaling read string");
          String s = BinaryData.stringFromBuffer(buffer);
          _signalReadString(s);
          break;
        case BINARY_TYPE_CUSTOM:
          _logger.finest("Signaling read buffer");
          _signalReadBuffer(buffer, BINARY_TYPE_CUSTOM);
          break;
        case BINARY_TYPE_FILE:
          if (_fileAsBuffer) {
            _signalReadBuffer(buffer, BINARY_TYPE_FILE);
            _logger.finest("Signaling read buffer");
          }
          else {
            _logger.finest("Signaling read file");
            _signalReadFile(buffer);
          }
          break;
        default:
          break;
      }
  }

  void _signalReadChunk(ByteBuffer buf, int signature, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadTcpChunk(_peer, buf, signature, bytes, bytesTotal);
    });
  }

  void _signalReadBuffer(ByteBuffer buffer, int binaryType) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerBuffer(_peer, buffer, binaryType);
    });
  }

  void _signalReadBlobChunk(Blob blob) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerBlobChunk(_peer, blob);
    });
  }

  void _signalReadBlob(Blob blob) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      //l.onPeerFile(_wrapper, new Blob([new Uint8Array.fromBuffer(buffer)]));
      l.onPeerFile(_peer, blob);
    });
  }
  void _signalReadFile(ByteBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      //l.onPeerFile(_wrapper, new Blob([new Uint8Array.fromBuffer(buffer)]));
      l.onPeerFile(_peer, new Blob([buffer]));
    });
  }

  void _signalReadString(String s) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerString(_peer, s);
    });
  }
}

