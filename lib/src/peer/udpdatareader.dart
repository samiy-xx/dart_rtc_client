part of rtc_client;

class UDPDataReader extends BinaryDataReader {
  static final _logger = new Logger("dart_rtc_client.UDPDataReader");
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
  Timer _ackTimer;
  const int _ackTransmitWaitMs = 5;
  AckBuffer _ackBuffer;
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
    _ackBuffer = new AckBuffer();
    _ackBuffer.onFull.listen(_ackBufferFull);
    _monitorAcks();
  }

  Future readChunkString(String s) {
    Completer c = new Completer();
    window.setImmediate(() {
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
    _lastProcessed = _startMs = new DateTime.now().millisecondsSinceEpoch;
    //_startMs = new DateTime.now().millisecondsSinceEpoch;
    int i = 0;

    if (BinaryData.isCommand(buf)) {
      _process_command(buf);
      return;
    }

    //DataView v = new DataView(buf);
    ByteData v = new ByteData.view(buf);
    int chunkLength = v.lengthInBytes;
    while (i < chunkLength) {

      if (_currentReadState == BinaryReadState.INIT_READ) {
        _process_init_read(v.getUint8(i));
        i += SIZEOF8;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_TYPE) {
        _process_read_type(v.getUint8(i));
        i += SIZEOF8;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_SEQUENCE) {
        _process_read_sequence(v.getUint32(i));
        i += SIZEOF32;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_TOTAL_SEQUENCES) {
        _process_read_total_sequences(v.getUint32(i));
        i += SIZEOF32;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_LENGTH) {
        _process_read_length(v.getUint16(i));
        i += SIZEOF16;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_TOTAL_LENGTH) {
        _process_read_total_length(v.getUint32(i));
        i += SIZEOF32;
        //continue;
      }

      if (_currentReadState == BinaryReadState.READ_SIGNATURE) {
        _process_read_signature(v.getUint32(i));
        i += SIZEOF32;
        //continue;
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
    window.setImmediate(() {
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
      ByteData partView = new ByteData.view(part, SIZEOF_UDP_HEADER);

      for (int j = 0; j < part.lengthInBytes - SIZEOF_UDP_HEADER; j++) {
        completeView.setUint8(k, partView.getUint8(j));
        k++;
      }
    }

    _sequencer.removeCollection(signature);
    _sequencer.clear();
    _watch.stop();
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

    if (_haveThisPart) {
      _logger.fine("have this part");
      _ackBuffer.add(_currentChunkSequence);
      _currentReadState = BinaryReadState.INIT_READ;
      return;
    }
    //var tmp = new Uint8List.view(buffer).sublist(SIZEOF_UDP_HEADER);
    //_latest = new Uint8List.fromList(tmp).buffer;
    _latest = buffer;
    //_leftToRead -= buffer.lengthInBytes - SIZEOF_UDP_HEADER;
    if (!_haveThisPart)
      _totalRead += buffer.lengthInBytes - SIZEOF_UDP_HEADER;

    //if (_leftToRead == 0) {
      _currentReadState = BinaryReadState.FINISH_READ;
      _process_end();
    //}
  }

  /*
   * Process end of read
   */
  void _process_end() {

    addToSequencer(_latest, _signature, _currentChunkSequence);
    if (!_haveThisPart) {
      //List<int> sequences = new List<int>(1);
      //sequences[0] = _currentChunkSequence;
      //ByteBuffer ack = BinaryData.createAck(_signature, sequences);
      //(_wrapper as DataPeerWrapper).binaryWriter.sendAck(ack);
      _ackBuffer.add(_currentChunkSequence);
      //(_wrapper as DataPeerWrapper).binaryWriter.writeAck(_signature, _currentChunkSequence);
      _signalReadChunk(_latest, _signature, _currentChunkSequence, _totalSequences, _currentChunkContentLength, _contentTotalLength);
    }
    //new Logger().Debug("Processed $_totalRead of $_contentTotalLength");
    int now = new DateTime.now().millisecondsSinceEpoch;

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
    var type = _packetType;
    if (sequencerComplete(_signature)) {
      buildCompleteBuffer(_signature, _contentTotalLength, _totalSequences).then((ByteBuffer buffer) {

        if (buffer != null)
          _doSignalingBasedOnBufferType(buffer, type);

      });
    }
    _contentTotalLength = 0;
    _totalRead = 0;


  }

  void _monitorAcks() {
    _ackTimer = new Timer.periodic(const Duration(milliseconds: 1), (Timer t) {
      if (_signature == null || _ackBuffer.length == 0)
        return;
      int now = new DateTime.now().millisecondsSinceEpoch;
      if ((_startMs + _ackTransmitWaitMs) < now) {
        ByteBuffer ack = BinaryData.createAck(_signature, _ackBuffer.acks);
        _ackBuffer.clear();
        if (_wrapper != null)
          (_wrapper as DataPeerWrapper).binaryWriter.sendAck(ack);

      }
    });
  }
  void _ackBufferFull(List<int> acks) {
    ByteBuffer ack = BinaryData.createAck(_signature, _ackBuffer.acks);
    if (_wrapper != null)
      (_wrapper as DataPeerWrapper).binaryWriter.sendAck(ack);
  }

  void _cancelMonitor() {
    if (_ackTimer != null) {
      _ackTimer.cancel();
      _ackTimer = null;
    }
  }

  void _doSignalingBasedOnBufferType(ByteBuffer buffer, int type) {

    switch (type) {
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

  void _process_command(ByteBuffer buffer) {
    int signature = BinaryData.getSignature(buffer);
    int contentLength = buffer.lengthInBytes - SIZEOF_UDP_HEADER;
    int sequenceCount = contentLength ~/ SIZEOF32;

    var byteData = new ByteData.view(buffer, SIZEOF_UDP_HEADER);
    for (int i = 0; i < sequenceCount; i++) {
      int sequence = byteData.getUint32(i * SIZEOF32);
      _signalSendSuccess(signature, sequence);
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
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
        l.onPeerReadUdpChunk(_wrapper, buf, signature, sequence, totalSequences, bytes, bytesTotal);
      });
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

class AckBuffer {
  StreamController<List<int>> _bufferyController;
  Stream<List<int>> onFull;
  const int ACK_LIMIT = 50;
  List<int> _acks;
  int _index = 0;
  bool get full => _index == ACK_LIMIT - 1;
  List<int> get acks => _getAcks();
  AckBuffer() {
    _acks = new List<int>(ACK_LIMIT);
    _bufferyController = new StreamController<List<int>>();
    onFull = _bufferyController.stream;
  }

  void add(int ack) {
    _acks[_index++] = ack;
    if (full) {
      _bufferyController.add(_acks);
      _index = 0;
      clear();
    }
  }

  int length()  {
    int count = 0;
    for (int i = 0; i < ACK_LIMIT; i++) {
      if (_acks[i] != null)
        count++;
    }
    return count;
  }

  void clear() {
    _acks = new List<int>(ACK_LIMIT);
    _index = 0;
  }

  List<int> _getAcks() {
    int l = length();
    List<int> r = new List<int>(l);
    int r_index = 0;
    for (int i = 0; i < _acks.length; i++) {
      if (_acks[i] != null) {
        r[r_index++] = _acks[i];
      }
    }
    return r;
  }
}