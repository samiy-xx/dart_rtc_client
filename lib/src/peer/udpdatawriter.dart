part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {
  Sequencer _sequencer;
  bool _canLoop = true;
  int _last;
  int _interval = 5;
  Timer _intervalTimer = null;

  UDPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_UDP, wrapper) {
    _sequencer = new Sequencer();
    _last = new DateTime.now().millisecondsSinceEpoch;
  }

  Future<int> send(ArrayBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(0);

    int totalSequences = (buffer.byteLength ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;

    int signature = new Random().nextInt(100000000);
    SequenceCollection sc = _sequencer.createNewSequenceCollection(signature, totalSequences);
    sc.completer = completer;

    while (read < buffer.byteLength) {
      int toRead = buffer.byteLength > _writeChunkSize ? _writeChunkSize : buffer.byteLength;
      ArrayBuffer b = addUdpHeader(
          buffer.slice(read, read + toRead),
          packetType,
          sequence,
          totalSequences,
          signature,
          buffer.byteLength
      );
      addSequence(signature, sequence, totalSequences, b, reliable);
      sequence++;
      read += toRead;
    }

    return completer.future;
  }

  void addSequence(int signature, int sequence, int total, ArrayBuffer buffer, bool resend) {
    var sse =  new SendSequenceEntry(sequence, buffer);
    sse.resend = resend;

    _sequencer.addSequence(signature, total, sse);
    setImmediate();
  }

  int removeSequence(int signature, int sequence) {
    SequenceCollection collection = _sequencer.getSequenceCollection(signature);
    if (collection == null)
      return null;

    SendSequenceEntry sse = collection.getEntry(sequence);
    if (sse == null)
      return null;

    //if (sse.completer != null && !sse.completer.isCompleted)
    //  sse.completer.complete(new DateTime.now().millisecondsSinceEpoch - sse.timeSent);

    _sequencer.removeSequence(signature, sequence);
    _signalWroteChunk(collection.signature, sse.sequence, collection.total, sse.data.byteLength);
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
        _send(sse.data);
        //new Logger().Debug("Sent chunk ${collection.signature} ${sse.sequence} RESEND = ${sse.resend} PACKETTYPE = ${BinaryData.getPacketType(sse.data)}");
        sse.markSent();
        _signalWriteChunk(collection.signature, sse.sequence, collection.total, sse.data.byteLength);
        if (!sse.resend)
          removeSequence(collection.signature, sse.sequence);
      } else {
        if ((sse.timeReSent + currentLatency) < now) {
          _roundTripCalculator.addToLatency(50);
          _send(sse.data);
          new Logger().Debug("RE-Sent chunk ${collection.signature} ${sse.sequence} RESEND = ${sse.resend} PACKETTYPE = ${BinaryData.getPacketType(sse.data)}");
          sse.markReSent();
        }
      }

    }

    if (_sequencer.hasMore() && _canLoop) {
      //new Logger().Debug("Has more");
      setImmediate();
    }
  }

  void writeAck(int signature, int sequence, int total) {
    //new Logger().Debug("WRITING ACK for $signature $sequence");
    addSequence(signature, 1, 1, BinaryData.createAck(signature, sequence), false);
  }

  void receiveAck(int signature, int sequence) {

    //new Logger().Debug("RECEIVE ACK for $signature $sequence");
    int timeSent = removeSequence(signature, sequence);
    if (timeSent != null)
      calculateLatency(timeSent);

  }

  void _signalWriteChunk(int signature, int sequence, int totalSequences, int bytes) {
    listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
      l.onWriteChunk(_wrapper, signature, sequence, totalSequences, bytes);
    });
  }

  void _signalWroteChunk(int signature, int sequence, int totalSequences, int bytes) {
    listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
      l.onWroteChunk(_wrapper, signature, sequence, totalSequences, bytes);
    });
  }

  void setImmediate() {
    if (_canLoop) {
      if (_intervalTimer != null)
        _intervalTimer.cancel();
      _intervalTimer = new Timer(const Duration(milliseconds: 5), _process);
    }
  }
}

