part of rtc_client;

class TCPDataReader extends BinaryDataReader {
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
  TCPDataReader(PeerWrapper wrapper) : super(wrapper) {

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
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_TYPE) {
        _process_read_type(v.getUint8(i));
        i += SIZEOF8;
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_LENGTH) {
        _process_read_length(v.getUint16(i));
        i += SIZEOF16;
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_TOTAL_LENGTH) {
        _process_read_total_length(v.getUint32(i));
        i += SIZEOF32;
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_SIGNATURE) {
        _process_read_signature(v.getUint32(i));
        i += SIZEOF32;
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_CONTENT) {
        if (leftToRead > 0) {
          _process_content(v.getUint8(i), i - SIZEOF_TCP_HEADER);
          i += SIZEOF8;
        }
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

  void _process_content(int b, int index) {

    try {
      _latestView.setUint8(index, b);
    } catch (e) {
      new Logger().Error("Error at index $index setting byte $b : exception $e");
    }

    _leftToRead -= SIZEOF8;
    _totalRead += SIZEOF8;


    if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      _process_end();
    }
  }

  void _process_end() {

    _signalReadChunk(_latest, _signature, _currentChunkContentLength, _contentTotalLength);

    //new Logger().Debug("Processed $_totalRead of $_contentTotalLength");
    if (_totalRead == _contentTotalLength)
      _processBuffer();

    _currentReadState = BinaryReadState.INIT_READ;
  }

  void _processBuffer() {
    _totalRead = 0;
    //_contentTotalLength = 0;
    //new Logger().Debug("Processing buffer");
    ByteBuffer buffer;
    //if (sequencerComplete(_signature)) {
      //new Logger().Debug("Sequence complete, building complete buffer");
      //buffer = buildCompleteBuffer(_signature);
    //}
    _contentTotalLength = 0;
    _totalRead = 0;
    //if (buffer != null)
      //_doSignalingBasedOnBufferType(buffer);
  }

  void _signalReadChunk(ByteBuffer buf, int signature, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadTcpChunk(_wrapper, buf, signature, bytes, bytesTotal);
    });
  }
}

