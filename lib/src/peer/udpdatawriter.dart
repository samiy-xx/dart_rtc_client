part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {
  Sequencer _sequencer;
  bool _canLoop = true;
  int _last;
  int _interval = 5;
  Timer _intervalTimer = null;

  UDPDataWriter() : super(BINARY_PROTOCOL_UDP) {
    _sequencer = new Sequencer();
    _last = new DateTime.now().millisecondsSinceEpoch;
  }

  Future<bool> send(ArrayBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    if (!reliable)
      completer.complete(true);
    
    int totalSequences = (buffer.byteLength ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
   
    int signature = new Random().nextInt(100000000);
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
      addSequence(signature, sequence, totalSequences, b, reliable, completer);
      sequence++;
      read += toRead;
    }

    return completer.future;
  }

  void addSequence(int signature, int sequence, int total, ArrayBuffer buffer, bool resend, Completer completer) {
    var sse =  new SendSequenceEntry(sequence, buffer);
    sse.resend = resend;
    sse.completer = completer;
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
    
    if (sse.completer != null && !sse.completer.isCompleted)
      sse.completer.complete(true);
    
    _sequencer.removeSequence(signature, sequence);
    return sse.timeSent;
  }

  void _process() {
    //new Logger().Debug("_process loop");
    /*if (_writeChannel.bufferedAmount > 0) {
      setImmediate();
      return;
    }*/
    int now = new DateTime.now().millisecondsSinceEpoch;
    List<SequenceCollection> collections = _sequencer.getCollections();

    for (int i = 0; i < collections.length; i++) {
      SequenceCollection collection = collections[i];
      SendSequenceEntry sse = collection.getFirst();
      //List<SequenceEntry> entries = collection.getFirstThree();
      //for (int j = 0; j < entries.length; j++) {
        //SendSequenceEntry sse = entries[j];
        
        if (sse == null)
          continue;
  
        if (!sse.sent) {
          _send(sse.data);
          //new Logger().Debug("Sent chunk ${collection.signature} ${sse.sequence} RESEND = ${sse.resend} PACKETTYPE = ${BinaryData.getPacketType(sse.data)}");
          sse.markSent();
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
      //}
    }

    if (_sequencer.hasMore() && _canLoop) {
      //new Logger().Debug("Has more");
      setImmediate();
    }
  }

  void writeAck(int signature, int sequence, int total) {
    //new Logger().Debug("WRITING ACK for $signature $sequence");
    addSequence(signature, 1, 1, BinaryData.createAck(signature, sequence), false, null);
  }

  void receiveAck(int signature, int sequence) {
    
    //new Logger().Debug("RECEIVE ACK for $signature $sequence");
    int timeSent = removeSequence(signature, sequence);
    if (timeSent != null)
      calculateLatency(timeSent);

  }

  void setImmediate() {
    if (_canLoop) {
      if (_intervalTimer != null)
        _intervalTimer.cancel();
      _intervalTimer = new Timer(const Duration(milliseconds: 5), _process);
    }
  }
}

