part of rtc_client_tests;

class MockTcpWriter extends TCPDataWriter {

  MockTcpWriter() : super(null);
  void _send(ByteBuffer buf) {

  }
}