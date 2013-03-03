part of rtc_client;

class UDPDataWriter extends BinaryDataWriter {
  /* Create Array buffer slices att his size for sending */
  int _writeChunkSize = 512;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  Map<int, List<StoreEntry>> _sentPackets;

  Timer _sendTimer;

  UDPDataWriter(RtcDataChannel c) : super(c) {
    _sentPackets = new Map<int, List<StoreEntry>>();
    _sendTimer = new Timer.repeating(const Duration(milliseconds: 50), _timerTick);
  }

  void send(ArrayBuffer buffer, int packetType) {
    int totalSequences = (buffer.byteLength ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
    int signature = new DateTime.now().millisecondsSinceEpoch  ~/1000;

    while (read < buffer.byteLength) {
      int toRead = buffer.byteLength > _writeChunkSize ? _writeChunkSize : buffer.byteLength;
      ArrayBuffer b = addHeader(
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
    int max = 5;

    _sentPackets.forEach((int key, List<StoreEntry> entries) {
      entries.sort((a, b) => a.compareTo(b));
      int sent = 0;
      if (_channel.bufferedAmount == 0) {
        for (int i = 0; i < entries.length; i++) {
          if (sent >= 5)
            continue;

          int now = new DateTime.now().millisecondsSinceEpoch;
          StoreEntry se = entries[i];


          if (se.sent) {
            if ((se.time + 150) < now) {
              _send(se.buffer, key, true);
              se.sent = true;
              se.time = now;
            }
          } else {
            _send(se.buffer, key, true);
            se.sent = true;
            se.time = now;
          }
          sent++;
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

  void writeAck(int signature, int sequence, [bool wrap = true]) {
    //new Logger().Debug("Creating ack");
    Object ack = BinaryData.createAck(signature, sequence);
    if (wrap)
      ack = wrapToString(ack);

    _channel.send(ack);
    //new Logger().Debug("Sent ack");
  }

  /**
   * send.. with possibility to wrap into a string because chrome doesnt like binary
   */
  void _send(ArrayBuffer buf, int time, bool wrap) {
    //new Logger().Debug("Sending $time ${BinaryData.getSequenceNumber(buf)}");
    Object toSend = wrap ? wrapToString(buf) : buf;
    _channel.send(toSend);
    //new Logger().Debug("Sent $time ${BinaryData.getSequenceNumber(buf)}");
  }

  void removeFromBuffer(int signature, int sequence) {
    StoreEntry se = findStoredBuffer(signature, sequence);

    if (se != null) {
      //new Logger().Debug("Removing stored entry ${signature} $sequence");
      _sentPackets[signature].remove(se);
      //new Logger().Debug("Removed stored entry ${signature} $sequence");
      if (_sentPackets[signature].length == 0) {
        new Logger().Debug("PAcket sent finished");
        _sentPackets.remove(signature);
      }
    }
  }

  void storeBuffer(ArrayBuffer buf, int signature, int sequence) {
    if (!_sentPackets.containsKey(signature))
      _sentPackets[signature] = new List<StoreEntry>();

    var se = new StoreEntry(sequence, buf);
    new Logger().Debug("Storing buffer $signature $sequence with size ${buf.byteLength} and is valid ${BinaryData.isValid(buf)}");
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

  String wrapToString(ArrayBuffer buf) {
    Uint8Array arr = new Uint8Array.fromBuffer(buf);
    return new String.fromCharCodes(arr.toList());
  }

  ArrayBuffer addHeader(ArrayBuffer buf, int packetType, int sequenceNumber, int totalSequences, int time, int total) {
    Uint8Array content = new Uint8Array.fromBuffer(buf);
    ArrayBuffer resultBuffer = new ArrayBuffer(buf.byteLength + 16);
    DataView writer = new DataView(resultBuffer);

    writer.setUint8(0, FULL_BYTE);
    writer.setUint8(1, packetType);
    writer.setUint16(2, sequenceNumber);
    writer.setUint16(4, totalSequences);
    writer.setUint16(6, buf.byteLength);
    writer.setUint32(8, total);
    writer.setUint32(12, time);

    for (int i = 0; i < content.length; i++) {
      writer.setUint8(i + 16, content[i]);
    }

    return writer.buffer;
  }
}

class StoreEntry implements Comparable{
  int time;
  int sequence;
  bool sent = false;
  ArrayBuffer buffer;

  StoreEntry(this.sequence, this.buffer) {
    time = new DateTime.now().millisecondsSinceEpoch;
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
