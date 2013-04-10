part of rtc_client_tests;

class UDPReaderTests {
  final String testString = "abcdefghijklmnopqrstuvwxyz01234567890";
  UDPDataReader reader;

  run() {
    group('UdpReaderTests', () {

      setUp(() {
        reader = new UDPDataReader(null);
      });

      tearDown(() {
      });

      test("BinaryDataReader, readChunk, can read a chunk", () {

      });
    });
  }
}



