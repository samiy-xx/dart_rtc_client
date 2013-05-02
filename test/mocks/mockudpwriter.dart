part of rtc_client_tests;

class MockUdpWriter extends UDPDataWriter {
  MockUdpWriter() : super(null);
  void _send(ByteBuffer buf) {

  }
}