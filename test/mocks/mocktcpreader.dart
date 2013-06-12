part of rtc_client_tests;

class MockTcpReader extends ByteReader {
  int read = 0;

  MockTcpReader() : super(null) {

  }

  void process_end() {
    read++;
    super.process_end();
  }
}