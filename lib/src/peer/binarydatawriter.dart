part of rtc_client;

abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  RtcDataChannel _channel;
  int _binaryProtocol;
  BinaryDataWriter(RtcDataChannel c) : super() {
    _channel = c;
  }

  void send(ArrayBuffer buffer, int packetType);

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

