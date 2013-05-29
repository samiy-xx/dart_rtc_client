part of rtc_client;


/**
 * BinaryDataWriter
 * Needs to be extended for udp and tcp
 */
abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  static final _logger = new Logger("dart_rtc_client.BinaryDataWriter");

  PeerWrapper _wrapper;

  // Datachannel where to write to
  RtcDataChannel _writeChannel;

  // Keeps track of latency
  RoundTripCalculator _roundTripCalculator;

  // While Chrome hates binary
  bool _wrapToString = true;

  // tcp udp
  int _binaryProtocol;

  // write only max this size chunks to data channel
  int _writeChunkSize = 550;

  /** Returns the current latency */
  int get currentLatency => _roundTripCalculator.currentLatency;

  /** Get the chunk size for writing */
  int get writeChunkSize => _writeChunkSize;

  /** Sets the chunk size for writing */
  set writeChunkSize(int i) => _writeChunkSize = i;

  /** Sets the write data channel */
  set dataChannel(RtcDataChannel c) => _writeChannel = c;

  BinaryDataWriter(int protocol, PeerWrapper wrapper) : super() {
    _binaryProtocol = protocol;
    _wrapper = wrapper;
    _roundTripCalculator = new RoundTripCalculator();
  }

  void sendAck(ByteBuffer buffer);
  //void writeAck(int signature, int sequence);
  Future<int> send(ByteBuffer buffer, int packetType, bool reliable);
  Future<int> sendFile(File f);

  void write(ByteBuffer buf) {
    try {
      var toSend = _wrapToString ? wrapToString(buf) : buf;
      _writeChannel.send(toSend);

    } on DomException catch(e, s) {
      _logger.severe("Error $e");
      _logger.severe("Trace $s");
      _logger.severe("Attempted to send buffer of ${buf.lengthInBytes} bytes");
      _logger.severe("Buffer valid = ${BinaryData.isValid(buf, _binaryProtocol)}");
      _logger.severe("Channel state = ${_writeChannel.readyState}");
    }
  }

  void calculateLatency(int time) {
    _roundTripCalculator.calculateLatency(time);
  }

  bool isValid(ByteBuffer buffer) {
    return BinaryData.isValid(buffer, _binaryProtocol);
  }

  String wrapToString(ByteBuffer buf) {
    return BinaryData.stringFromBuffer(buf);
  }

  ByteBuffer addUdpHeader(ByteBuffer buf, int packetType, int sequenceNumber, int totalSequences, int signature, int total) {
    return BinaryData.writeUdpHeader(buf, packetType, sequenceNumber, totalSequences, signature, total);
  }

  ByteBuffer addTcpHeader(ByteBuffer buf, int packetType, int signature, int total) {
    return BinaryData.writeTcpHeader(buf, packetType, signature, total);
  }
}

