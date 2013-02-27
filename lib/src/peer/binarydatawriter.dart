part of rtc_client;

class BinaryDataWriter extends BinaryData {
  /* Create Array buffer slices att his size for sending */
  int _writeChunkSize = 128;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  RtcDataChannel _channel;

  BinaryDataWriter() : super() {

  }

  BinaryDataWriter.forChannel(RtcDataChannel c) : super() {
    _channel = c;
  }

  ArrayBuffer createPacketBuffer(Packet p) {
    String packet = PacketFactory.get(p);

    ArrayBuffer buffer = new ArrayBuffer(packet.length);
    DataView data = new DataView(buffer);
    int i = 0;
    while (i < packet.length) {
      data.setUint8(i, packet.codeUnitAt(i));
      i++;
    }
    return buffer;
  }

  int _calculateHeaderSize(BinaryDataType t) {
    int out = 0;
    if (t == BinaryDataType.PACKET)
      out = 3;
    else if (t == BinaryDataType.STRING)
      out = 4;
    else if (t == BinaryDataType.FILE)
      out = 6;
    return out;
  }

  int _calculateFooterSize() {
    return 3;
  }

  /**
   * Bit ugly
   * TODO: Make pretty
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
        send(b, sequence, totalSequences, wrapToString);
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
      send(b, 1, 1, wrapToString);
    }
  }

  /**
   * send.. with possibility to wrap into a string because chrome doesnt like binary
   */
  void send(ArrayBuffer buf, int sequence, int total, bool wrap) {
    if (!hasHeader(buf))
      return;

    Object toSend = wrap ? wrapToString(buf, sequence, total) : buf;
    _channel.send(toSend);
  }

  String wrapToString(ArrayBuffer buf, int sequence, int total) {
    Uint16Array arr = new Uint16Array.fromBuffer(buf);
    StringBuffer sb = new StringBuffer();
    sb.write("S($sequence)($total)");
    sb.write(new String.fromCharCodes(arr.toList()));
    sb.write("E($sequence)");
    return sb.toString();
  }

  /**
   * Needs a bit of tuning =)
   */
  bool hasHeader(ArrayBuffer buffer) {
    DataView view = new DataView(buffer);
    try {
      if (view.getUint8(0) == 0xFF)
        return true;
    } catch (e) {}

    return false;
  }

  ArrayBuffer addHeader(ArrayBuffer buf, int sequenceNumber, int totalSequences, int time, int total) {
    Uint8Array content = new Uint8Array.fromBuffer(buf);
    ArrayBuffer resultBuffer = new ArrayBuffer(buf.byteLength + 15);
    DataView writer = new DataView(resultBuffer);

    writer.setUint8(0, BinaryData.FULL_BYTE);
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

  ArrayBuffer createHeaderFor(BinaryDataType t, int length) {
    ArrayBuffer buffer = new ArrayBuffer(_calculateHeaderSize(t));
    DataView data = new DataView(buffer);

    // Write 0xFF at start
    data.setUint8(0, BinaryData.FULL_BYTE);
    // Write data type
    data.setUint8(1, t.toInt());
    // Write content length
    if (t == BinaryDataType.PACKET) {
      // Takes 1 byte
      data.setUint8(2, length);
    } else if (t == BinaryDataType.STRING) {
      // Takes 2 bytes
      data.setUint16(2, length);
    } else {
      // takes 4 bytes
      data.setUint32(2, length);
    }

    return buffer;
  }

  ArrayBuffer createFooterFor(BinaryDataType t) {
    ArrayBuffer buffer = new ArrayBuffer(3);
    DataView data = new DataView(buffer);

    // Set 0x00 at start
    data.setUint8(0, BinaryData.NULL_BYTE);
    // Write data type
    data.setUint8(1, t.toInt());
    // Set 0x00 at end
    data.setUint8(2, BinaryData.NULL_BYTE);

    return buffer;
  }

  ArrayBuffer mergeHeaderTo(ArrayBuffer buffer, BinaryDataType t) {
    // Content buffer should have all Uint8 so can just use byteLength
    ArrayBuffer resultBuffer = new ArrayBuffer(buffer.byteLength + _calculateHeaderSize(t));
    ArrayBuffer headerBuffer = createHeaderFor(t, buffer.byteLength);

    Uint8Array contentArrayView = new Uint8Array.fromBuffer(buffer);
    DataView headerView = new DataView(headerBuffer);
    DataView resultView = new DataView(resultBuffer);


    resultView.setUint8(0, headerView.getUint8(0));
    resultView.setUint8(1, headerView.getUint8(1));
    if (t == BinaryDataType.PACKET)
      resultView.setUint8(2, headerView.getUint8(2));
    else if (t == BinaryDataType.PACKET)
      resultView.setUint16(2, headerView.getUint16(2));
    else if (t == BinaryDataType.FILE)
      resultView.setUint32(2, headerView.getUint32(2));


    for (int i = 0; i < contentArrayView.length; i++) {
      resultView.setUint8(i + 3, contentArrayView[i]);
    }
    return resultBuffer;
  }

  ArrayBuffer mergeFooterTo(ArrayBuffer buffer, BinaryDataType t) {
    Uint8Array a = new Uint8Array.fromBuffer(buffer);
    Uint8Array b = new Uint8Array.fromBuffer(createFooterFor(t));

    ArrayBuffer resultBuffer = new ArrayBuffer(a.length + b.length);
    Uint8Array writer = new Uint8Array.fromBuffer(resultBuffer);

    writer.setElements(a, 0);
    int position = a.length;
    writer.setElements(b, position);

    return resultBuffer;
  }
}