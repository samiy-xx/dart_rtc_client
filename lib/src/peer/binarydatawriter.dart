part of rtc_client;

abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  RtcDataChannel _channel;
  RoundTripCalculator _roundTripCalculator;

  int _binaryProtocol;

  int _writeChunkSize = 500;

  int get currentLatency => _roundTripCalculator.currentLatency;
  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  bool _wrapToString;

  set dataChannel(RtcDataChannel c) => _channel = c;
  BinaryDataWriter(int protocol) : super() {
    _binaryProtocol = protocol;
    _roundTripCalculator = new RoundTripCalculator();
    // while chrome doesnt support sending arraybuffer
    _wrapToString = true;
  }

  removeFromBuffer(int signature, int sequence);
  receiveAck(int signature, int sequence);
  Future<int> writeAck(int signature, int sequence, [bool wrap]);
  void send(ArrayBuffer buffer, int packetType);

  Future<int> _send(ArrayBuffer buf, bool wrap) {
    var toSend = wrap ? wrapToString(buf) : buf;
    _channel.send(toSend);
  }

  void calculateLatency(int time) {
    _roundTripCalculator.calculateLatency(time);
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

