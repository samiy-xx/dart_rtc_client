part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {
  static final _logger = new Logger("dart_rtc_client.UDPDataWriter");
  const int MAX_SEND_TRESHOLD = 200;
  const int START_SEND_TRESHOLD = 50;
  const int ELAPSED_TIME_AFTER_SEND = 200;
  const int MAX_FILE_BUFFER_SIZE = 1024 * 1024 * 20;

  Timer _observerTimer;
  SendQueue _queue;
  int _c_packetsToSend;
  int _c_leftToRead;
  int _c_read;
  int _currentSequence;
  int resendCount = 0;
  int currentTreshold = 0;
  int _lastSendTime;

  UDPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_UDP, wrapper) {
    _queue = new SendQueue();
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    _clearSequenceNumber();
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(0);
    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;

    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    int signature = new Random().nextInt(100000000);
    _send(buffer, signature, totalSequences, buffer.lengthInBytes, packetType).then((int i) {
      if (!completer.isCompleted)
        completer.complete(1);
    });
    return completer.future;
  }

  Future<int> sendFile(Blob file) {
    _clearSequenceNumber();
    Completer completer = new Completer();
    FileReader reader = new FileReader();
    int totalSequences = _getSequenceTotal(file.size);

    int read = 0;
    int leftToRead = file.size;
    int signature = new Random().nextInt(100000000);
    int toRead = file.size > MAX_FILE_BUFFER_SIZE ? MAX_FILE_BUFFER_SIZE : file.size;
    reader.readAsArrayBuffer(file.slice(read, read + toRead));
    reader.onLoadEnd.listen((ProgressEvent e) {
      _send(reader.result, signature, totalSequences, file.size, BINARY_TYPE_FILE).then((int i) {
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

  Future<int> _send(ByteBuffer buffer, int signature, int totalSequences, int totalLength, int packetType) {
    currentTreshold = START_SEND_TRESHOLD;
    Completer<int> completer = new Completer<int>();
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    StreamSubscription sub;
    sub = _queue.onEmpty.listen((bool b) {
      _adjustTreshold();

      resendCount = 0;
      if (_observerTimer != null)
        _observerTimer.cancel();

      if (leftToRead == 0) {
        sub.cancel();
        completer.complete(1);
        return;
      }

      int t = (leftToRead /writeChunkSize).ceil();
      int treshold = t < currentTreshold ? t : currentTreshold;

      int added = 0;
      _queue.prepare(treshold);
      while (added < treshold) {
        int toRead = leftToRead > _writeChunkSize ? _writeChunkSize : leftToRead;
        ByteBuffer toAdd = new Uint8List.fromList(new Uint8List.view(buffer).sublist(read, read+toRead));

        ByteBuffer b = addUdpHeader(
            toAdd,
            packetType,
            _currentSequence,
            totalSequences,
            signature,
            totalLength
        );

        read += toRead;
        leftToRead -= toRead;
        var si = new SendItem(b, _currentSequence, signature);
        si.totalSequences = totalSequences;
        si.signature = signature;

        _queue.add(si);
        _currentSequence++;
        added++;
        si.markSent();
        _signalWriteChunk(si.signature, si.sequence, si.totalSequences, si.buffer.lengthInBytes - SIZEOF_UDP_HEADER);
        write(si.buffer);
      }

      observe();
      /*int now = new DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < _queue.itemCount; i++) {
        SendItem si = _queue.items[i];
        si.markSent();
        _signalWriteChunk(si.signature, si.sequence, si.totalSequences, si.buffer.lengthInBytes - SIZEOF_UDP_HEADER);
        write(si.buffer);
      }*/
    });
    _queue.initialize();
    return completer.future;
  }

  int _getSequenceTotal([int bytes = 36056912]) {
    int total = 0;
    int leftToRead = bytes;
    while (leftToRead > 0) {
      int b = leftToRead > MAX_FILE_BUFFER_SIZE ? MAX_FILE_BUFFER_SIZE : leftToRead;
      total += (b / _writeChunkSize).ceil();
      leftToRead -= b;
    }
    return total;
  }

  void _clearSequenceNumber() {
    _currentSequence = 1;
  }

  void observe() {
    _observerTimer = new Timer.periodic(const Duration(milliseconds: 5), (Timer t) {
      if (_queue.itemCount > 0) {
        int now = new DateTime.now().millisecondsSinceEpoch;
        SendItem item = _queue.first();

        if ((item.sendTime + ELAPSED_TIME_AFTER_SEND) < now) {
          item.sendTime = now;
          write(item.buffer);
          resendCount++;
        }
      }
    });
  }

  void _adjustTreshold() {
    if (resendCount > 0) {
      currentTreshold--;
    } else {
      currentTreshold = currentTreshold >= MAX_SEND_TRESHOLD ? MAX_SEND_TRESHOLD : currentTreshold + 1;
    }
  }

  void writeAck(int signature, int sequence) {
    new Timer(const Duration(milliseconds: 0), () {
      write(BinaryData.createAck(signature, sequence));
    });
  }

  void sendAck(ByteBuffer buffer) {
    new Timer(const Duration(milliseconds: 0), () {
      write(buffer);
    });
  }

  void receiveAck(int signature, int sequence) {
    new Timer(const Duration(milliseconds: 0), () {
      var si = _queue.removeItem(signature, sequence);
      if (si != null) {

        _signalWroteChunk(si.signature, si.sequence, si.totalSequences, si.buffer.lengthInBytes - SIZEOF_UDP_HEADER);
      }
    });
  }

  void _signalWriteChunk(int signature, int sequence, int totalSequences, int bytes) {
    new Timer(const Duration(milliseconds: 0), () {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWriteChunk(_wrapper, signature, sequence, totalSequences, bytes);
      });
    });
  }

  void _signalWroteChunk(int signature, int sequence, int totalSequences, int bytes) {
    new Timer(const Duration(milliseconds: 0), () {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWroteChunk(_wrapper, signature, sequence, totalSequences, bytes);
      });
    });
  }
}

class SendQueue {
  StreamController<bool> _queueEmptyController;
  Stream<bool> onEmpty;
  List<SendItem> _items;
  int _index;
  List<SendItem> get items => _items;
  int get itemCount => _length();

  SendQueue() {
    _queueEmptyController = new StreamController<bool>();
    onEmpty = _queueEmptyController.stream;
  }

  void prepare(int count) {
    _index = 0;
    _items = new List<SendItem>(count);
  }

  void write() {

  }

  void add(SendItem item) {
    _items[_index++] = item;
  }

  SendItem removeItem(int signature, int sequence) {
    SendItem item = null;
    //_items.removeWhere((SendItem i) => i.signature == signature && i.sequence == sequence);
    for (int i = 0; i < items.length ; i++) {
      SendItem si = items[i];
      if (si != null) {
        if (si.signature == signature && si.sequence == sequence) {
          item = si;

          _items[i] = null;
          break;
        }
      }
    }

    if (_length() == 0) {

      if (_queueEmptyController.hasListener)
        _queueEmptyController.add(true);
    }
    return item;
  }

  SendItem first() {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i] != null)
        return _items[i];
    }
    return null;
  }

  int _length() {
    int count = 0;
    for (int i = 0; i < _items.length; i++) {
      if (_items[i] != null)
      count++;
    }
    return count;
  }
  void initialize() {
    if (_queueEmptyController.hasListener)
      _queueEmptyController.add(true);
  }
}

class SendItem {
  ByteBuffer buffer;
  int signature;
  int sequence;
  int totalSequences;
  int sendTime;
  bool sent = false;
  SendItem(this.buffer, this.sequence, this.signature);

  void markSent() {
    sent = true;
    sendTime = new DateTime.now().millisecondsSinceEpoch;
  }
}

