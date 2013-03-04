part of rtc_client;

abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  RtcDataChannel _channel;
  int _binaryProtocol;
  /* Create Array buffer slices att his size for sending */
  int _writeChunkSize = 512;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  bool _wrapToString;

  set wrapToString(bool v) => _wrapToString = v;

  set dataChannel(RtcDataChannel c) => _channel = c;
  BinaryDataWriter(int protocol) : super() {
    _binaryProtocol = protocol;

    // while chrome doesnt support sending arraybuffer
    _wrapToString = true;
  }
  removeFromBuffer(int signature, int sequence);
  Future<int> writeAck(int signature, int sequence, [bool wrap]);
  void send(ArrayBuffer buffer, int packetType);

  Future<int> _send(ArrayBuffer buf, bool wrap) {

    var toSend = wrap ? wrapToString(buf) : buf;
    _channel.send(toSend);

  }

  bool isValid(ArrayBuffer buffer) {
    return BinaryData.isValid(buffer, _binaryProtocol);
  }

  String wrapToString(ArrayBuffer buf) {
    Uint8Array arr = new Uint8Array.fromBuffer(buf);
    return new String.fromCharCodes(arr.toList());
  }

  ArrayBuffer addUdpHeader(ArrayBuffer buf, int packetType, int sequenceNumber, int totalSequences, int signature, int total) {
    return BinaryData.writeUdpHeader(buf, packetType, sequenceNumber, totalSequences, signature, total);
  }

  ArrayBuffer addTcpHeader(ArrayBuffer buf, int packetType, int signature, int total) {
    return BinaryData.writeTcpHeader(buf, packetType, signature, total);
  }
}

