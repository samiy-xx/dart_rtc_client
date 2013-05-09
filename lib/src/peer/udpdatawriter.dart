part of rtc_client;

class SendItem {
  ByteBuffer buffer;
  int signature;
  int sequence;

  SendItem(this.buffer, this.sequence, this.signature);
}
class UDPDataWriter extends BinaryDataWriter {
  List<SendItem> _sentItems;
  Completer _completer;
  Timer _intervalTimer = null;
  int _startSend;

  UDPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_UDP, wrapper) {
    _sentItems = new List<SendItem>();
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    _startSend = new DateTime.now().millisecondsSinceEpoch;
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(0);

    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    int signature = new Random().nextInt(100000000);
    _completer = completer;

    while (read < buffer.lengthInBytes) {
      int toRead = leftToRead > _writeChunkSize ? _writeChunkSize : leftToRead;
      ByteBuffer toAdd = new Uint8List.fromList(new Uint8List.view(buffer).sublist(read, read+toRead));
      ByteBuffer b = addUdpHeader(
          toAdd,
          packetType,
          sequence,
          totalSequences,
          signature,
          buffer.lengthInBytes
      );
      _signalWriteChunk(signature, sequence, totalSequences, toAdd.lengthInBytes);
      write(b);
      _signalWroteChunk(signature, sequence, totalSequences, toAdd.lengthInBytes);
      _sentItems.add(new SendItem(b, sequence, signature));
      sequence++;
      read += toRead;
      leftToRead -= toRead;
    }
    _setImmediate();
    return completer.future;
  }

  void _process() {
    if (_sentItems.length == 0)
      _completer.complete(new DateTime.now().millisecondsSinceEpoch - _startSend);
    else
      _setImmediate();
  }

  void writeAck(int signature, int sequence, int total) {
    new Timer(const Duration(milliseconds: 0), () {
      write(BinaryData.createAck(signature, sequence));
    });
  }

  void receiveAck(int signature, int sequence) {
    new Timer(const Duration(milliseconds: 0), () {
      _sentItems.removeWhere((SendItem i) => i.signature == signature && i.sequence == sequence);

      if (_sentItems.length == 0)
        print("sentItems empty");
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

  void _setImmediate() {
    if (_intervalTimer != null)
      _intervalTimer.cancel();
    _intervalTimer = new Timer(const Duration(milliseconds: 5), _process);
  }
}


class UDPDataWriterOld extends BinaryDataWriter {
  Sequencer _sequencer;
  bool _canLoop = true;
  int _last;
  int _interval = 5;
  Timer _intervalTimer = null;
  int _start = 0;
  int loops;
  int sent;
  UDPDataWriterOld(PeerWrapper wrapper) : super(BINARY_PROTOCOL_UDP, wrapper) {
    _sequencer = new Sequencer();
    _last = new DateTime.now().millisecondsSinceEpoch;
  }

  Future<int> send(ByteBuffer buffer, int packetType, bool reliable) {
    print("buffer to be sent ${buffer.lengthInBytes}");
    loops = 0;
    sent = 0;
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(0);

    int totalSequences = (buffer.lengthInBytes ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    int signature = new Random().nextInt(100000000);
    SequenceCollection sc = _sequencer.createNewSequenceCollection(signature, totalSequences);
    sc.completer = completer;

    while (read < buffer.lengthInBytes) {
      int toRead = leftToRead > _writeChunkSize ? _writeChunkSize : leftToRead;
      ByteBuffer toAdd = new Uint8List.fromList(new Uint8List.view(buffer).sublist(read, read+toRead));
      ByteBuffer b = addUdpHeader(
          //buffer.slice(read, read + toRead),
          toAdd,
          packetType,
          sequence,
          totalSequences,
          signature,
          buffer.lengthInBytes
      );
      //addSequence(signature, sequence, totalSequences, b, reliable);
      write(b);
      sequence++;
      read += toRead;
      leftToRead -= toRead;
    }
    setImmediate();
    return completer.future;
  }

  void addSequence(int signature, int sequence, int total, ByteBuffer buffer, bool resend) {
    var sse =  new SendSequenceEntry(sequence, buffer);
    sse.resend = resend;

    _sequencer.addSequence(signature, total, sse);

  }

  int removeSequence(int signature, int sequence) {
    SequenceCollection collection = _sequencer.getSequenceCollection(signature);
    if (collection == null)
      return null;

    SendSequenceEntry sse = collection.getEntry(sequence);
    if (sse == null)
      return null;

    _sequencer.removeSequence(signature, sequence);
    if (!BinaryData.isCommand(sse.data))
      _signalWroteChunk(collection.signature, sse.sequence, collection.total, sse.data.lengthInBytes);
    return sse.timeSent;
  }

  void _process() {

    int now = new DateTime.now().millisecondsSinceEpoch;
    List<SequenceCollection> collections = _sequencer.getCollections();

    for (int i = 0; i < collections.length; i++) {
      SequenceCollection collection = collections[i];
      SendSequenceEntry sse = collection.getFirst();

      if (sse == null)
        continue;

      if (!sse.sent) {
        write(sse.data);
        sent++;
        //new Logger().Debug("Sent chunk ${collection.signature} ${sse.sequence} RESEND = ${sse.resend} PACKETTYPE = ${BinaryData.getPacketType(sse.data)} ${sse.data.lengthInBytes}");
        sse.markSent();
        _signalWriteChunk(collection.signature, sse.sequence, collection.total, sse.data.lengthInBytes);
        if (!sse.resend)
          removeSequence(collection.signature, sse.sequence);
      } else {

          if ((sse.timeReSent + currentLatency) < now) {
            //_roundTripCalculator.addToLatency(10);
            write(sse.data);
            new Logger().Debug("RE-Sent chunk ${collection.signature} ${sse.sequence} RESEND = ${sse.resend} PACKETTYPE = ${BinaryData.getPacketType(sse.data)}");
            sse.markReSent();
          }
      }

    }

    if (_sequencer.hasMore() && _canLoop) {
      setImmediate();
    } else {
      print("loops $loops sent $sent");
    }
    loops++;
    int now2 = new DateTime.now().millisecondsSinceEpoch;
    //print (now2 - now);
  }

  void writeAck(int signature, int sequence, int total) {
    new Timer(const Duration(milliseconds: 0), () {
      write(BinaryData.createAck(signature, sequence));
      //addSequence(signature, 1, 1, BinaryData.createAck(signature, sequence), false);
    });
  }

  void receiveAck(int signature, int sequence) {
    int timeSent = removeSequence(signature, sequence);
    if (timeSent != null)
      calculateLatency(timeSent);
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

  void setImmediate() {
    if (_canLoop) {
      if (_intervalTimer != null)
        _intervalTimer.cancel();
      _intervalTimer = new Timer(const Duration(milliseconds: 0), _process);
    }
  }
}

