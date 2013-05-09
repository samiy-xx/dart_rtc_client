part of rtc_client;

class UDPDataReader extends BinaryDataReader {
  ByteBuffer _latest;
  ByteData _latestView;

  Sequencer _sequencer;
  int _lastProcessed;
  /* Length of data for currently processed object */
  int _length;

  /* Left to read on current packet */
  int _leftToRead = 0;
  int _totalRead = 0;
  int _currentChunkContentLength;
  int _contentTotalLength;
  int _currentChunkSequence;
  int _totalSequences;
  int _packetType;
  int _signature;
  int _startMs;
  int _testMS = 0;
  Stopwatch _watch;
  BinaryReadState _currentReadState = BinaryReadState.INIT_READ;
  BinaryReadState get currentReadState => _currentReadState;

  int get leftToRead => _leftToRead;

  bool _haveThisPart = false;
  Timer _timer;

  UDPDataReader(PeerWrapper wrapper) : super(wrapper) {
    _length = 0;
    _sequencer = new Sequencer();
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;
    _watch = new Stopwatch();
  }

  Future readChunkString(String s) {
    Completer c = new Completer();
    window.setImmediate(() {
      _startMs = new DateTime.now().millisecondsSinceEpoch;
      readChunk(BinaryData.bufferFromString(s));
      c.complete();
    });
    return c.future;
  }

  /**
   * Reads an ArrayBuffer
   * Can be whole packet or partial
   */
  void readChunk(ByteBuffer buf) {
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;

    int i = 0;

    if (BinaryData.isCommand(buf)) {
      _process_command(BinaryData.getCommand(buf), buf);
      return;
    }

    //DataView v = new DataView(buf);
    ByteData v = new ByteData.view(buf);
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

      if (_currentReadState == BinaryReadState.READ_SEQUENCE) {
        _process_read_sequence(v.getUint16(i));
        i += SIZEOF16;
        continue;
      }

      if (_currentReadState == BinaryReadState.READ_TOTAL_SEQUENCES) {
        _process_read_total_sequences(v.getUint16(i));
        i += SIZEOF16;
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

      /*if (_currentReadState == BinaryReadState.READ_CONTENT) {
        if (leftToRead > 0) {
          _process_content(v.getUint8(i), i - 16);
          i += SIZEOF8;
        }
      }*/
      if (_currentReadState == BinaryReadState.READ_CONTENT) {
        _process_content_v2(buf);
        i += buf.lengthInBytes - SIZEOF_UDP_HEADER;
      }
    }
  }

  bool haveCurrentPart() {
    return _sequencer.hasSequence(_signature, _currentChunkSequence);
  }

  void addToSequencer(ByteBuffer buffer, int signature, int sequence) {
    SequenceCollection sc = _sequencer.createNewSequenceCollection(signature, _totalSequences);
    sc.setEntry(new SequenceEntry(sequence, buffer));
  }

  Future<ByteBuffer> buildCompleteBuffer(int signature, int totalLength, int totalSequences) {
    Completer<ByteBuffer> completer = new Completer<ByteBuffer>();
    new Timer(const Duration(milliseconds: 0), () {
      completer.complete(_buildCompleteBuffer(signature, totalLength, totalSequences));
    });
    return completer.future;
  }

  ByteBuffer _buildCompleteBuffer(int signature, int totalLength, int totalSequences) {
    _watch.reset();
    _watch.start();
    SequenceCollection sc = _sequencer.getSequenceCollection(signature);
    ByteBuffer complete = new Uint8List(totalLength).buffer;
    ByteData completeView = new ByteData.view(complete);
    int k = 0;
    for (int i = 0; i < totalSequences; i++) {
      ByteBuffer part = sc.getEntry(i + 1).data;
      ByteData partView = new ByteData.view(part);

      for (int j = 0; j < part.lengthInBytes; j++) {
        completeView.setUint8(k, partView.getUint8(j));
        k++;
      }
    }

    _sequencer.removeCollection(signature);
    _watch.stop();
    //print("Built a buffer of ${complete.byteLength} bytes in ${_watch.elapsedMilliseconds} milliseconds");
    return complete;
  }

  bool sequencerComplete(int signature) {
    return _sequencer.getSequenceCollection(signature).isComplete;
  }

  ByteBuffer getLatestChunk() {
    return _latest;
  }

  /*
   * Read the 0xFF byte and switch state
   */
  void _process_init_read(int b) {
    if (b == FULL_BYTE) {
      _currentReadState = BinaryReadState.READ_TYPE;
    }
  }

  /*
   * Read the BinaryDataType of the object
   */
  void _process_read_type(int b) {
    _packetType = b;
    _currentReadState = BinaryReadState.READ_SEQUENCE;
  }

  void _process_read_sequence(int b) {
    _currentChunkSequence = b;
    _currentReadState = BinaryReadState.READ_TOTAL_SEQUENCES;
  }

  void _process_read_total_sequences(int b) {
    _totalSequences = b;
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
    if (b != _signature) {
      _totalRead = 0;
    }
    _signature = b;
    _currentReadState = BinaryReadState.READ_CONTENT;
    _haveThisPart = haveCurrentPart();
  }

  void _process_content_v2(ByteBuffer buffer) {
    //Uint8List l = new Uint8List.view(buffer, SIZEOF_UDP_HEADER);
    //print(l.length);
    //Uint8List ll = new Uint8List.view(_latest);
    //int index = ll.length;
    //for (int i = 0; i < l.length; i++) {
      //print("insert to ${index + i}");
    //  ll[i] = l[i];
    //}
    var tmp = new Uint8List.view(buffer).sublist(SIZEOF_UDP_HEADER);
    _latest = new Uint8List.fromList(tmp).buffer;
    _leftToRead -= buffer.lengthInBytes - SIZEOF_UDP_HEADER;
    if (!_haveThisPart)
      _totalRead += buffer.lengthInBytes - SIZEOF_UDP_HEADER;

    if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      _process_end();
    }
  }

  void _process_content(int b, int index) {

    try {
      _latestView.setUint8(index, b);
    } catch (e) {
      new Logger().Error("Error at index $index setting byte $b : exception $e");
    }

    _leftToRead -= SIZEOF8;
    //if (!_haveThisPart) {
      _totalRead += SIZEOF8;

    //}

    if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      _process_end();
    }
  }

  /*
   * Process end of read
   */
  void _process_end() {

    addToSequencer(_latest, _signature, _currentChunkSequence);
    if (!_haveThisPart)
      _signalReadChunk(_latest, _signature, _currentChunkSequence, _totalSequences, _currentChunkContentLength, _contentTotalLength);

    //new Logger().Debug("Processed $_totalRead of $_contentTotalLength");
    if (_totalRead == _contentTotalLength)
      _processBuffer();

    _currentReadState = BinaryReadState.INIT_READ;
  }

  /*
   * Process the buffer contents
   */
  void _processBuffer() {
    _totalRead = 0;
    ByteBuffer buffer;
    if (sequencerComplete(_signature)) {
      buildCompleteBuffer(_signature, _contentTotalLength, _totalSequences).then((ByteBuffer buffer) {

        if (buffer != null)
          _doSignalingBasedOnBufferType(buffer);

      });
    }
    _contentTotalLength = 0;
    _totalRead = 0;


  }

  void _doSignalingBasedOnBufferType(ByteBuffer buffer) {
      switch (_packetType) {
        case BINARY_TYPE_STRING:
          String s = BinaryData.stringFromBuffer(buffer);
          _signalReadString(s);
          break;
        case BINARY_TYPE_CUSTOM:
          _signalReadBuffer(buffer);
          break;
        case BINARY_TYPE_FILE:
          _signalReadFile(buffer);
          break;
        default:
          break;
      }
  }

  void _process_command(int command, ByteBuffer buffer) {

    switch (command) {
      case BINARY_PACKET_ACK:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        _signalSendSuccess(signature, sequence);
        break;
      default:
        break;
    }
  }

  // TODO: Move to writer
  void _signalSendSuccess(int signature, int sequence) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerSendSuccess(signature, sequence);
    });
  }

  /*
   * Signal listeners that a chunk has been read
   */
  void _signalReadChunk(ByteBuffer buf, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadUdpChunk(_wrapper, buf, signature, sequence, totalSequences, bytes, bytesTotal);
    });
  }

  void _signalReadBuffer(ByteBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerBuffer(_wrapper, buffer);
    });
  }

  void _signalReadFile(ByteBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      //l.onPeerFile(_wrapper, new Blob([new Uint8Array.fromBuffer(buffer)]));
      l.onPeerFile(_wrapper, new Blob([buffer]));
    });
  }

  void _signalReadString(String s) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerString(_wrapper, s);
    });
  }
  /**
   * Resets the reader
   */
  void reset() {
    _currentReadState = BinaryReadState.INIT_READ;
    _leftToRead = 0;
  }
}