part of rtc_client;

class UDPDataReader extends BinaryDataReader {

  ArrayBuffer _latest;
  DataView _latestView;
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

  /* Current read state */
  BinaryReadState _currentReadState = BinaryReadState.INIT_READ;

  /** Current read state */
  BinaryReadState get currentReadState => _currentReadState;

  int get leftToRead => _leftToRead;

  Map<int, Map<int, ArrayBuffer>> _sequencer_;
  bool _haveThisPart = false;
  Timer _timer;

  UDPDataReader(PeerWrapper wrapper) : super(wrapper) {
    _length = 0;
    _sequencer_ = new Map<int, Map<int, ArrayBuffer>>();
    _sequencer = new Sequencer();
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;
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
  void readChunk(ArrayBuffer buf) {
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;

    int i = 0;

    if (BinaryData.isCommand(buf)) {
      _process_command(BinaryData.getCommand(buf), buf);
      return;
    }

    DataView v = new DataView(buf);
    int chunkLength = v.byteLength;
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

      if (_currentReadState == BinaryReadState.READ_CONTENT) {
        if (leftToRead > 0) {
          _process_content(v.getUint8(i), i - 16);
          i += SIZEOF8;
        }
      }

    }

  }

  bool haveCurrentPart() {
    return _sequencer.hasSequence(_signature, _currentChunkSequence);
  }

  void addToSequencer(ArrayBuffer buffer, int signature, int sequence) {
    SequenceCollection sc = _sequencer.createNewSequenceCollection(signature, _totalSequences);
    sc.setEntry(new SequenceEntry(sequence, buffer));
  }

  ArrayBuffer buildCompleteBuffer(int signature) {
    SequenceCollection sc = _sequencer.getSequenceCollection(signature);
    ArrayBuffer complete = new ArrayBuffer(_contentTotalLength);
    DataView completeView = new DataView(complete);
    int k = 0;
    for (int i = 0; i < _totalSequences; i++) {
      ArrayBuffer part = sc.getEntry(i + 1).data;
      DataView partView = new DataView(part);

      for (int j = 0; j < part.byteLength; j++) {
        completeView.setUint8(k, partView.getUint8(j));
        k++;
      }
    }

    _sequencer.removeCollection(signature);
    return complete;
  }

  bool sequencerComplete(int signature) {
    return _sequencer.getSequenceCollection(signature).isComplete;
  }

  ArrayBuffer getLatestChunk() {
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
    _latest = new ArrayBuffer(b);
    _latestView = new DataView(_latest);
    _currentReadState = BinaryReadState.READ_TOTAL_LENGTH;
  }

  void _process_read_total_length(int b) {
    _contentTotalLength = b;
    _currentReadState = BinaryReadState.READ_SIGNATURE;
  }

  void _process_read_signature(int b) {
    if (b != _signature) {
      print("---------- SIGNATURE CHANGED --------------");
      _totalRead = 0;
    }
    _signature = b;
    _currentReadState = BinaryReadState.READ_CONTENT;
    _haveThisPart = haveCurrentPart();
  }

  /*
   * Push data to buffer
   */
  void _process_content(int b, int index) {

    try {
      _latestView.setUint8(index, b);
    } catch (e) {
      new Logger().Error("Error at index $index setting byte $b : exception $e");
    }

    _leftToRead -= SIZEOF8;
    if (!_haveThisPart) {
      _totalRead += SIZEOF8;

    }

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

    if (_totalRead == _contentTotalLength)
      _processBuffer();

    _currentReadState = BinaryReadState.INIT_READ;

  }

  /*
   * Process the buffer contents
   */
  void _processBuffer() {
    _totalRead = 0;
    //_contentTotalLength = 0;
    new Logger().Debug("Processing buffer");
    ArrayBuffer buffer;
    if (sequencerComplete(_signature)) {
      new Logger().Debug("Sequence complete, building complete buffer");
      buffer = buildCompleteBuffer(_signature);
    }
    _contentTotalLength = 0;
    _totalRead = 0;
    if (buffer != null)
      _doSignalingBasedOnBufferType(buffer);
  }

  void _doSignalingBasedOnBufferType(ArrayBuffer buffer) {
      switch (_packetType) {
        case BINARY_TYPE_STRING:
          String s = BinaryData.stringFromBuffer(buffer);
          _signalReadString(s);
          break;
        // TODO: BINARY_TYPE_PACKET should be somethign that application implements. remove
        /*case BINARY_TYPE_PACKET:
          Map m = json.parse(BinaryData.stringFromBuffer(buffer));
          if (m.containsKey('packetType')) {
            int packetType = m['packetType'];
            PeerPacket p;
            switch (packetType) {
              case PeerPacket.TYPE_DIRECTORY_ENTRY:
                new Logger().Debug("(binarydatareader.dart) _processBuffer Directory entry packet");
                p = DirectoryEntryPacket.fromMap(m);
                break;
              case PeerPacket.TYPE_REQUEST_FILE:
                new Logger().Debug("(binarydatareader.dart) _processBuffer Request file packet");
                p = RequestFilePacket.fromMap(m);
                break;
              default:
                p = null;
                break;
            }
            _signalReadPacket(p);
          }
          break;*/
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

  void _process_command(int command, ArrayBuffer buffer) {

    switch (command) {
      case BINARY_PACKET_ACK:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        _signalSendSuccess(signature, sequence);
        break;
      case BINARY_PACKET_RESEND:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        //_signalResend(signature, sequence);
        break;
      case BINARY_PACKET_REQUEST_RESEND:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        //_signalRequestResend(signature, sequence);
        break;
      default:
        break;
    }
  }

  void _signalSendSuccess(int signature, int sequence) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerSendSuccess(signature, sequence);
    });
  }

  /*
   * Signal listeners that a chunk has been read
   */
  void _signalReadChunk(ArrayBuffer buf, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerReadChunk(_wrapper, buf, signature, sequence, totalSequences, bytes, bytesTotal);
    });
  }

  void _signalReadBuffer(ArrayBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerBuffer(_wrapper, buffer);
    });
  }

  void _signalReadFile(ArrayBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPeerFile(_wrapper, new Blob([new Uint8Array.fromBuffer(buffer)]));
    });
  }

  /*
   * Packet has been read
   */
  //void _signalReadPacket(PeerPacket p) {
  //  listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
  //    l.onPeerPacket(_wrapper, p);
  //  });
  //}

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