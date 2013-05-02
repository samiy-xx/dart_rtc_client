part of rtc_client_tests;

class TcpWriterTests {
  MockTcpWriter writer;
  String testString;
  const int CHUNK_SIZE = 50;
  const int STRING_LENGTH = 1000;
  run() {
    group('TcpWriterTests', () {

      setUp(() {
        writer = new MockTcpWriter();
        writer.writeChunkSize = CHUNK_SIZE;
        testString = "0987654321"+ TestUtils.genRandomString(STRING_LENGTH) + "1234567890";
      });

      tearDown(() {

      });

      test("TcpWriter, Sends data", () {
        int expected = STRING_LENGTH ~/ CHUNK_SIZE + 1;
        ByteBuffer buffer = BinaryData.bufferFromString(testString);
        writer.send(buffer, BINARY_TYPE_CUSTOM).then((a) {
          expect(writer.sentData, isTrue);
          expect(writer.packetsSent, equals(expected));
        });
      });
    });
  }
}