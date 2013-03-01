part of rtc_client;

class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener>{
  /* Create Array buffer slices att his size for sending */
  int _writeChunkSize = 128;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  Map<int, List<ArrayBuffer>> _sentPackets;

  RtcDataChannel _channel;

  BinaryDataWriter(RtcDataChannel c) : super() {
    _channel = c;
    _sentPackets = new Map<int, List<ArrayBuffer>>();
  }

  Future<int> writeAsync(ArrayBuffer buffer, int packetType, [bool wrapToString = false]) {
    Completer completer = new Completer<int>();
    write(buffer, packetType, wrapToString);
    completer.complete(buffer.byteLength);
    return completer.future;
  }

  /**
   * Bit ugly
   * TODO: Make pretty
   * TODO: Also, learn to code something else than shit.
   */
  void write(ArrayBuffer buffer, int packetType, [bool wrapToString = false]) {
    int totalSequences = (buffer.byteLength ~/ _writeChunkSize) + 1;
    int sequence = 1;
    int read = 0;
    int time = new DateTime.now().millisecondsSinceEpoch  ~/1000;
    new Logger().Debug("binarydatawriter.dart writing ${buffer.byteLength} in ${totalSequences} chunks");
    if (buffer.byteLength > _writeChunkSize) {
      while (read < buffer.byteLength) {
        ArrayBuffer b = addHeader(
            buffer.slice(read, read + _writeChunkSize),
            packetType,
            sequence,
            totalSequences,
            time,
            buffer.byteLength
        );
        send(b, time, sequence, totalSequences, wrapToString);
        read += _writeChunkSize;
        sequence++;
      }
    } else {
      ArrayBuffer b = addHeader(
          buffer,
          packetType,
          1,
          1,
          time,
          buffer.byteLength
      );
      send(b, time, 1, 1, wrapToString);
    }
  }

  void writeAck(ArrayBuffer b, [bool wrap = true]) {
    Object ack = BinaryData.createAck(b);
    if (wrap)
      ack = wrapToString(ack, 1, 1);

    _channel.send(ack);
  }

  /**
   * send.. with possibility to wrap into a string because chrome doesnt like binary
   */
  void send(ArrayBuffer buf, int time, int sequence, int total, bool wrap) {
    if (!BinaryData.isValid(buf)) {
      new Logger().Debug("Data is not valid");
      return;
    }
    storeBuffer(buf, time);
    Object toSend = wrap ? wrapToString(buf, sequence, total) : buf;
    new Logger().Debug("Sending $toSend");
    _channel.send(toSend);
  }

  void removeFromBuffer(int time, int sequence) {
    ArrayBuffer b = findStoredBuffer(time, sequence);
    if (b != null) {
      _sentPackets[time].remove(b);
      if (_sentPackets[time].length == 0) {
        _sentPackets.remove(time);
      }
    }
  }

  void storeBuffer(ArrayBuffer buf, int time) {
    if (!_sentPackets.containsKey(time))
      _sentPackets[time] = new List<ArrayBuffer>();

    _sentPackets[time].add(buf);
  }

  ArrayBuffer findStoredBuffer(int time, int sequence) {
    if (!_sentPackets.containsKey(time))
      return null;

    for (int i = 0; i < _sentPackets[time].length; i++) {
      ArrayBuffer buf = _sentPackets[time][i];
      DataView view = new DataView(buf, 0 , 14);
      if (view.getUint16(1) == sequence)
        return buf;
    }

    return null;
  }

  String wrapToString(ArrayBuffer buf, int sequence, int total) {
    Uint8Array arr = new Uint8Array.fromBuffer(buf);
    //StringBuffer sb = new StringBuffer();
    //sb.write("S($sequence)($total)");
    //sb.write(new String.fromCharCodes(arr.toList()));
    //sb.write("E($sequence)");
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