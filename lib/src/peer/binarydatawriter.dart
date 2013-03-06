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

  
  Future<bool> _send(ArrayBuffer buf, bool wrap) {
    Completer completer = new Completer();
    try {
      var toSend = wrap ? wrapToString(buf) : buf;
      _channel.send(toSend);
      completer.complete(true);
    } on DomException catch(e, s) {
      new Logger().Error("Error $e");
      new Logger().Error("Trace $s");
      new Logger().Error("Attempted to send buffer of ${buf.byteLength} bytes");
      new Logger().Error("Buffer valid = ${BinaryData.isValid(buf, _binaryProtocol)}");
      new Logger().Error("Channel state = ${_channel.readyState}");
      completer.complete(false);
    }
    return completer.future;
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

