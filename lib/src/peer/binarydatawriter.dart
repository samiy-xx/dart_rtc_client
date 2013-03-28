part of rtc_client;

/**
 * BinaryDataWriter
 * Needs to be extended for udp and tcp
 */
abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  // Datachannel where to write to
  RtcDataChannel _writeChannel;

  // Keeps track of latency
  RoundTripCalculator _roundTripCalculator;

  // While Chrome hates binary
  bool _wrapToString = true;

  // tcp udp
  int _binaryProtocol;

  // write only max this size chunks to data channel
  int _writeChunkSize = 512;

  /** Returns the current latency */
  int get currentLatency => _roundTripCalculator.currentLatency;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  /** Sets the write data channel */
  set dataChannel(RtcDataChannel c) => _writeChannel = c;

  BinaryDataWriter(int protocol) : super() {
    _binaryProtocol = protocol;
    _roundTripCalculator = new RoundTripCalculator();
  }

  void writeAck(int signature, int sequence, int total);
  Future<bool> send(ArrayBuffer buffer, int packetType);

  void _send(ArrayBuffer buf, bool wrap) {
    try {
      var toSend = wrap ? wrapToString(buf) : buf;
      _writeChannel.send(toSend);
    } on DomException catch(e, s) {
      new Logger().Error("Error $e");
      new Logger().Error("Trace $s");
      new Logger().Error("Attempted to send buffer of ${buf.byteLength} bytes");
      new Logger().Error("Buffer valid = ${BinaryData.isValid(buf, _binaryProtocol)}");
      new Logger().Error("Channel state = ${_writeChannel.readyState}");
    }
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

