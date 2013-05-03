part of rtc_client_tests;

class MockUdpWriter extends UDPDataWriter {
  bool sentData = false;
  int packetsSent = 0;
  List<ByteBuffer> buffers;

  MockUdpWriter() : super(null) {
    buffers = new List<ByteBuffer>();
  }

  void write(ByteBuffer buf) {
    sentData = true;
    packetsSent++;
    buffers.add(buf);
  }
}