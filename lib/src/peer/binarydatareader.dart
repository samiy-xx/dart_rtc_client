part of rtc_client;

class BinaryDataReader extends GenericEventTarget<BinaryDataEventListener> {

  ArrayBuffer _latest;
  DataView _latestView;

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
  /* Buffer for unfinished data */
  List<int> _buffer;

  /** Currently buffered unfinished data */
  int get buffered => _buffer.length;

  /* Current read state */
  BinaryReadState _currentReadState = BinaryReadState.INIT_READ;

  /** Current read state */
  BinaryReadState get currentReadState => _currentReadState;

  int get leftToRead => _leftToRead;

  Map<int, Map<int, ArrayBuffer>> _sequencer;

  Timer _timer;
  RtcDataChannel _channel;
  /**
   * da mighty constructor
   */
  BinaryDataReader(RtcDataChannel c) : super() {
    new Logger().Debug("Binarydatareader.dart constructor, assigning channel on message");
    _channel = c;
    _channel.onMessage.listen(_onChannelMessage);
    _length = 0;
    _buffer = new List<int>();
    _sequencer = new Map<int, Map<int, ArrayBuffer>>();
    _timer = new Timer.repeating(const Duration(milliseconds: 10), timerTick);
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;
  }

  void _onChannelMessage(MessageEvent e) {
    new Logger().Debug("(binarydatareader.dart) _onChannelMessage");
    if (e.data is Blob) {
      throw new NotImplementedException("Blob is not implemented");
    }

    else if (e.data is ArrayBuffer) {
      readChunk(e.data);
    }

    else if (e.data is ArrayBufferView) {
      readChunk((e.data as ArrayBufferView).buffer);
    }

    else {
      new Logger().Debug("(binarydatareader.dart) reading string");
      readChunkString(e.data);
    }
  }

  void readChunkString(String s) {
    new Logger().Debug("Read chunk string");
    readChunk(BinaryData.bufferFromString(s));
  }

  /**
   * Reads an ArrayBuffer
   * Can be whole packet or partial
   */
  void readChunk(ArrayBuffer buf) {
    _lastProcessed = new DateTime.now().millisecondsSinceEpoch;

    new Logger().Debug("Read chunk");

    int i = 0;
    if (!BinaryData.isValid(buf)) {
      new Logger().Debug("Data not valid");
    }

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
    //_latest = buf;
    //_signalReadChunk(signature, chunkSequence, chunkTotalSequences, contentLength, contentTotalLength);
  }

  void timerTick(Timer t) {
    int now = new DateTime.now().millisecondsSinceEpoch;
    if (now > _lastProcessed + 1000) {

    }
  }

  void addToSequencer(ArrayBuffer buffer, int signature, int sequence) {
    new Logger().Debug("add to sequencer");
    if (!_sequencer.containsKey(signature)) {
      _sequencer[signature] = new Map<int, ArrayBuffer>();
      new Logger().Debug("Created sequencer entry for $signature");
    }

    if (!_sequencer[signature].containsKey(sequence)) {
      _sequencer[signature][sequence] = buffer;
      new Logger().Debug("Created entry for $sequence");
    }
  }

  ArrayBuffer buildCompleteBuffer(int signature) {
    ArrayBuffer complete = new ArrayBuffer(_contentTotalLength);
    DataView completeView = new DataView(complete);
    int k = 0;
    for (int i = 0; i < _totalSequences; i++) {
      ArrayBuffer part = _sequencer[signature][i + 1];
      DataView partView = new DataView(part);

      for (int j = 0; j < part.byteLength; j++) {
        completeView.setUint8(k, partView.getUint8(j));
        k++;
      }
    }

    _sequencer.remove(signature);

    return complete;
  }

  bool sequencerComplete(int signature) {
    for (int i = 0; i < _totalSequences; i++) {
      if (!_sequencer[signature].containsKey(i + 1))
        return false;
    }
    return true;
  }

  ArrayBuffer getLatestChunk() {
    return _latest;
  }

  /*
   * Read the 0xFF byte and switch state
   */
  void _process_init_read(int b) {

    new Logger().Debug("_process_init_read");
    if (b == FULL_BYTE) {
      _currentReadState = BinaryReadState.READ_TYPE;
      new Logger().Debug("_process_init_read set state READ_TYPE");
    }
  }

  /*
   * Read the BinaryDataType of the object
   */
  void _process_read_type(int b) {
    _packetType = b;
    _currentReadState = BinaryReadState.READ_SEQUENCE;
    new Logger().Debug("_process_read_type $b set state READ_SEQUENCE");
  }

  void _process_read_sequence(int b) {
    _currentChunkSequence = b;
    _currentReadState = BinaryReadState.READ_TOTAL_SEQUENCES;
    new Logger().Debug("_process_read_sequence $b set state READ_TOTAL_SEQUENCES");
  }

  void _process_read_total_sequences(int b) {
    _totalSequences = b;
    _currentReadState = BinaryReadState.READ_LENGTH;
    new Logger().Debug("_process_read_total_sequences $b set state RrEAD_LENGTH");
  }

  void _process_read_length(int b) {
    _currentChunkContentLength = b;
    _leftToRead = b;
    _latest = new ArrayBuffer(b);
    _latestView = new DataView(_latest);
    _currentReadState = BinaryReadState.READ_TOTAL_LENGTH;
    new Logger().Debug("_process_read_length $b set state READ_TOTAL_LENGTH");
  }

  void _process_read_total_length(int b) {
    _contentTotalLength = b;
    _currentReadState = BinaryReadState.READ_SIGNATURE;
    new Logger().Debug("_process_read_total_length $b set state READ_SIGNATURE");
  }

  void _process_read_signature(int b) {
    _signature = b;
    _currentReadState = BinaryReadState.READ_CONTENT;
    new Logger().Debug("_process_read_signture $b set state READ_CONTENT");
  }

  /*
   * Push data to buffer
   */
  void _process_content(int b, int index) {
    //_buffer.add(b);
    _latestView.setUint8(index, b);
    _leftToRead -= SIZEOF8;
    _totalRead += SIZEOF8;

    if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      _process_end();
    }
  }

  /*
   * Process end of read
   */
  void _process_end() {
    new Logger().Debug("_process_end");
    _currentReadState = BinaryReadState.INIT_READ;
    addToSequencer(_latest, _signature, _currentChunkSequence);
    _signalReadChunk(_latest, _signature, _currentChunkSequence, _totalSequences, _currentChunkContentLength, _leftToRead);

    new Logger().Debug("$_totalRead $_contentTotalLength");
    if (_totalRead == _contentTotalLength)
      _processBuffer();
  }

  /*
   * Process the buffer contents
   */
  void _processBuffer() {
    _totalRead = 0;

    ArrayBuffer buffer;
    if (sequencerComplete(_signature)) {
      buffer = buildCompleteBuffer(_signature);
    }
    if (buffer != null) {


      switch (_packetType) {
        case BINARY_TYPE_STRING:
          String s = BinaryData.stringFromBuffer(buffer);
          _signalReadString(s);
          break;
        case BINARY_TYPE_PACKET:
          String s = BinaryData.stringFromBuffer(buffer);
          Packet p = PacketFactory.getPacketFromString(s);
          _signalReadPacket(p);
          break;
        case BINARY_TYPE_FILE:
          _signalReadBuffer(buffer);
          break;
        default:
          break;
      }
    }

  }

  void _process_command(int command, ArrayBuffer buffer) {
    new Logger().Debug("(binarydatareader.dart) Processing command");
    switch (command) {
      case BINARY_PACKET_ACK:
        break;
      case BINARY_PACKET_RESEND:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        _signalResend(signature, sequence);
        break;
      case BINARY_PACKET_REQUEST_RESEND:
        int signature = BinaryData.getSignature(buffer);
        int sequence = BinaryData.getSequenceNumber(buffer);
        _signalRequestResend(signature, sequence);
        break;
      default:
        break;
    }
  }

  void bufferFromBlob(Blob b) {
    FileReader r = new FileReader();
    r.readAsArrayBuffer(b);

    r.onLoadEnd.listen((ProgressEvent e) {
      listeners.where((l) => l is BinaryBlobReadEventListener).forEach((BinaryBlobReadEventListener l) {
        l.onLoadDone(r.result);
      });
    });

    r.onProgress.listen((ProgressEvent e) {
      listeners.where((l) => l is BinaryBlobReadEventListener).forEach((BinaryBlobReadEventListener l) {
        l.onProgress();
      });
    });
  }

  void _signalRequestResend(int signature, int sequence) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onRemoteRequestResend(signature, sequence);
    });
  }

  void _signalResend(int signature, int sequence) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onLocalRequestResend(signature, sequence);
    });
  }
  /*
   * Signal listeners that a chunk has been read
   */
  void _signalReadChunk(ArrayBuffer buf, int signature, int sequence, int totalSequences, int bytes, int bytesLeft) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onReadChunk(buf, signature, sequence, totalSequences, bytes, bytesLeft);
    });
  }

  void _signalReadBuffer(ArrayBuffer buffer) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onBuffer(buffer);
    });
  }
  /*
   * Packet has been read
   */
  void _signalReadPacket(Packet p) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onPacket(p);
    });
  }

  void _signalReadString(String s) {
    listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
      l.onString(s);
    });
  }
  /**
   * Resets the reader
   */
  void reset() {
    _buffer.clear();
    _currentReadState = BinaryReadState.INIT_READ;
    _leftToRead = 0;
  }

}