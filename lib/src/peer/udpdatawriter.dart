part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {
  const int MAX_SEND_TRESHOLD = 100;
  static final _logger = new Logger("dart_rtc_client.UDPDataWriter");
  const int START_SEND_TRESHOLD = 5;
  const int ELAPSED_TIME_AFTER_SEND = 500;

  Timer _observerTimer;
  SendQueue _queue;
  int _c_packetsToSend;
  int _c_leftToRead;
  int _c_read;
  int _currentSequence;
  int resendCount = 0;
  int currentTreshold = 0;

  UDPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_UDP, wrapper) {
    _queue = new SendQueue();
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(0);
    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;
    _currentSequence = 1;
    //int sequence = 1;
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    int signature = new Random().nextInt(100000000);
    _send(buffer, signature, totalSequences, buffer.lengthInBytes, packetType).then((int i) {
      if (!completer.isCompleted)
        completer.complete(1);
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
        print("Cancel sub");
        sub.cancel();
        completer.complete(1);
        return;
      }

      int t = (leftToRead ~/ writeChunkSize) + 1;
      int treshold = t < currentTreshold ? t : currentTreshold;

      int added = 0;
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
      }

      observe();
      int now = new DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < _queue.itemCount; i++) {
        SendItem si = _queue.items[i];
        si.markSent();
        _signalWriteChunk(si.signature, si.sequence, si.totalSequences, si.buffer.lengthInBytes - SIZEOF_UDP_HEADER);
        write(si.buffer);
      }
    });
    _queue.initialize();
    return completer.future;
  }

  void observe() {
    _observerTimer = new Timer.periodic(const Duration(milliseconds: 10), (Timer t) {
      if (_queue.itemCount > 0) {
        int now = new DateTime.now().millisecondsSinceEpoch;
        SendItem item = _queue.items[0];
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

  void receiveAck(int signature, int sequence) {
    new Timer(const Duration(milliseconds: 0), () {
      var si = _queue.removeItem(signature, sequence);
      if (si != null)
        _signalWroteChunk(si.signature, si.sequence, si.totalSequences, si.buffer.lengthInBytes - SIZEOF_UDP_HEADER);
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

  List<SendItem> get items => _items;
  int get itemCount => _items.length;

  SendQueue() {
    _items = new List<SendItem>();
    _queueEmptyController = new StreamController<bool>();
    onEmpty = _queueEmptyController.stream;
  }

  void write() {

  }
  void add(SendItem item) {
    _items.add(item);

  }

  SendItem removeItem(int signature, int sequence) {
    SendItem item = null;
    //_items.removeWhere((SendItem i) => i.signature == signature && i.sequence == sequence);
    for (int i = 0; i < items.length ; i++) {
      SendItem si = items[i];
      if (si.signature == signature && si.sequence == sequence) {
        item = items.removeAt(i);
        break;
      }
    }

    if (_items.length == 0)
      if (_queueEmptyController.hasListener)
        _queueEmptyController.add(true);

    return item;
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

