part of rtc_client_tests;

class MockTcpWriter extends TCPDataWriter {
  bool sentData = false;
  int packetsSent = 0;
  List<ByteBuffer> buffers;
  MockTcpReader _reader;

  MockTcpWriter(MockTcpReader reader) : super(null) {
    _reader = reader;
    buffers = new List<ByteBuffer>();
    wrapToString = false;
  }

  void write(ByteBuffer buf) {
    sentData = true;
    packetsSent++;
    buffers.add(buf);
    _reader.readChunk(buf);
  }
}