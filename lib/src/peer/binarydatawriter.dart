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

  Future<int> writeAsync(ArrayBuffer buffer, [bool wrapToString = false]) {
    Completer completer = new Completer<int>();
    write(buffer, wrapToString);
    completer.complete(buffer.byteLength);
    return completer.future;
  }

  /**
   * Bit ugly
   * TODO: Make pretty
   * TODO: Also, learn to code something else than shit.
   */
  void write(ArrayBuffer buffer, [bool wrapToString = false]) {
    int totalSequences = buffer.byteLength ~/ _writeChunkSize;
    int sequence = 1;
    int read = 0;
    int time = new DateTime.now().millisecondsSinceEpoch;

    if (buffer.byteLength > _writeChunkSize) {
      while (read < buffer.byteLength) {
        ArrayBuffer b = addHeader(
            buffer.slice(read, read + _writeChunkSize),
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
          1,
          1,
          time,
          buffer.byteLength
      );
      send(b, time, 1, 1, wrapToString);
    }
  }

  /**
   * send.. with possibility to wrap into a string because chrome doesnt like binary
   */
  void send(ArrayBuffer buf, int time, int sequence, int total, bool wrap) {
    if (!BinaryData.isValid(buf))
      return;

    storeBuffer(buf, time);
    Object toSend = wrap ? wrapToString(buf, sequence, total) : buf;

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
    Uint16Array arr = new Uint16Array.fromBuffer(buf);
    StringBuffer sb = new StringBuffer();
    sb.write("S($sequence)($total)");
    sb.write(new String.fromCharCodes(arr.toList()));
    sb.write("E($sequence)");
    return sb.toString();
  }

  ArrayBuffer addHeader(ArrayBuffer buf, int sequenceNumber, int totalSequences, int time, int total) {
    Uint8Array content = new Uint8Array.fromBuffer(buf);
    ArrayBuffer resultBuffer = new ArrayBuffer(buf.byteLength + 15);
    DataView writer = new DataView(resultBuffer);

    writer.setUint8(0, FULL_BYTE);
    writer.setUint16(1, sequenceNumber);
    writer.setUint16(3, totalSequences);
    writer.setUint16(5, buf.byteLength);
    writer.setUint32(7, total);
    writer.setUint32(11, time);

    for (int i = 0; i < content.length; i++) {
      writer.setUint8(i + 15, content[i]);
    }

    return writer.buffer;
  }
}