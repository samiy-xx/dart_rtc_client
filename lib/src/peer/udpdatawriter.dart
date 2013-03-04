part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {

  Map<int, List<StoreEntry>> _sentPackets;

  Timer _sendTimer;
  int _currentSequence = 0;
  int _currentLatency = 50;
  bool _canSend = true;
  int _lastSent = 0;

  UDPDataWriter() : super(BINARY_PROTOCOL_UDP) {
    _sentPackets = new Map<int, List<StoreEntry>>();
    _sendTimer = new Timer.repeating(const Duration(milliseconds: 1), _timerTick);
  }

  void send(ArrayBuffer buffer, int packetType) {
    int totalSequences = (buffer.byteLength ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
    int signature = new DateTime.now().millisecondsSinceEpoch  ~/1000;

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
      storeBuffer(b, signature, sequence);
      sequence++;
      read += toRead;
    }
  }

  void _timerTick(Timer t) {
    int now = new DateTime.now().millisecondsSinceEpoch;

    //if (_lastSent + (_currentLatency * 2) < now) {
    //  _canSend = true;
    //}

    _sentPackets.forEach((int key, List<StoreEntry> entries) {

      if (_channel.bufferedAmount == 0 && entries.length > 0) {
        StoreEntry entry = entries[0];
        if (!entry.sent) {
          _send(entry.buffer, true);
          //new Logger().Debug("Sent chunk ${entry.sequence}");
          entry.markSent();
        } else {
          if (entry.timeSent + (_currentLatency + 5) < now) {
            _send(entry.buffer, true);
            //new Logger().Debug("Sent chunk ${entry.sequence}");
            entry.markSent();
          }
        }
      }
    });

  }

  Future<int> writeAsync(ArrayBuffer buffer, int packetType, [bool wrapToString = false]) {
    Completer completer = new Completer<int>();
    //write(buffer, packetType, wrapToString);
    completer.complete(buffer.byteLength);
    return completer.future;
  }


  ArrayBuffer findSentData(int signature, int sequence) {
    if (!_sentPackets.containsKey(signature));
      return null;

    List<StoreEntry> buffers = _sentPackets[signature];
    for (int i = 0; i < buffers.length; i++) {
      StoreEntry se = buffers[i];

      if (se.sequence == sequence)
        return se.buffer;
    }

    return null;
  }

  Future<int> writeAck(int signature, int sequence, [bool wrap = true]) {
   Completer<int> c = new Completer<int>();
    Object ack = BinaryData.createAck(signature, sequence);
    if (wrap)
      ack = wrapToString(ack);

    _channel.send(ack);
    c.complete(1);
    return c.future;
  }

  void removeFromBuffer(int signature, int sequence) {
    StoreEntry se = findStoredBuffer(signature, sequence);
    int now = new DateTime.now().millisecondsSinceEpoch;

    if (se != null) {
      _currentLatency = now - se.timeSent;
      //new Logger().Debug("Latency is $_currentLatency");
      //new Logger().Debug("Removing stored entry ${signature} $sequence");
      _sentPackets[signature].remove(se);
      //new Logger().Debug("Removed stored entry ${signature} $sequence");
      if (_sentPackets[signature].length == 0) {
        //new Logger().Debug("PAcket sent finished");
        _sentPackets.remove(signature);
      }
    }
  }

  void storeBuffer(ArrayBuffer buf, int signature, int sequence) {
    if (!_sentPackets.containsKey(signature))
      _sentPackets[signature] = new List<StoreEntry>();

    var se = new StoreEntry(sequence, buf);
    //new Logger().Debug("Storing buffer $signature $sequence with size ${buf.byteLength} and is valid ${isValid(buf)}");
    _sentPackets[signature].add(se);
  }

  StoreEntry findStoredBuffer(int time, int sequence) {
    if (!_sentPackets.containsKey(time))
      return null;

    for (int i = 0; i < _sentPackets[time].length; i++) {
      StoreEntry se = _sentPackets[time][i];

      if (se.sequence == sequence)
        return se;
    }

    return null;
  }

}

class StoreEntry implements Comparable{
  int timeStored;
  int timeSent;
  int sequence;
  bool sent = false;
  ArrayBuffer buffer;

  StoreEntry(this.sequence, this.buffer) {
    timeStored = new DateTime.now().millisecondsSinceEpoch;
  }

  void markSent() {
    sent = true;
    timeSent = new DateTime.now().millisecondsSinceEpoch;
  }

  int compareTo(StoreEntry e) {
    if (!sent && e.sent)
      return -1;

    if (sent && e.sent)
      return 0;

    if (!sent && !e.sent)
      return 0;

    if (sent && !e.sent)
      return 1;
  }
}
