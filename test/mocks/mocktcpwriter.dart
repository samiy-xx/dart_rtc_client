part of rtc_client_tests;

class MockTcpWriter extends TCPDataWriter {
  bool sentData = false;
  int packetsSent = 0;
  List<ByteBuffer> buffers;

  MockTcpWriter() : super(null) {
    buffers = new List<ByteBuffer>();
  }

  void write(ByteBuffer buf) {
    sentData = true;
    packetsSent++;
    buffers.add(buf);
  }
}