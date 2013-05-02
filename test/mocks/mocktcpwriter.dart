part of rtc_client_tests;

class MockTcpWriter extends TCPDataWriter {
  bool sentData = false;
  int packetsSent = 0;
  MockTcpWriter() : super(null);
  void write(ByteBuffer buf) {
    sentData = true;
    packetsSent++;
  }
}