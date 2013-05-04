part of rtc_client_tests;

class UdpWriterTests {
  MockUdpWriter writer;
  String testString;
  ByteBuffer buffer;
  int expectedPacketCount;

  const int CHUNK_SIZE = 50;
  const int STRING_LENGTH = 1000;


  run() {
    group('UdpWriterTests', () {

      setUp(() {
        writer = new MockUdpWriter();
        writer.writeChunkSize = CHUNK_SIZE;
        testString = "0987654321"+ TestUtils.genRandomString(STRING_LENGTH) + "1234567890";
        buffer = BinaryData.bufferFromString(testString);
        expectedPacketCount = STRING_LENGTH ~/ CHUNK_SIZE + 1;
      });

      tearDown(() {

      });

      test("UdpWriter, Send, Sends data", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, true).then((int ms) {
          expectAsync1(ms) {
            expect(writer.sentData, isTrue);
            print(writer.sentData);
          }
        });
      });

      test("UdpWriter, Send, Splits bytebuffer in chunks", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, false).then((int ms) {
          expectAsync1(ms) {
            expect(writer.packetsSent, equals(expectedPacketCount));
            expect(writer.buffers.length, equals(expectedPacketCount));
          }
        });
      });

      test("UdpWriter, Send, Each chunk is valid tcp packet", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, false).then((int ms) {
          expectAsync1(ms) {
            for (var buffer in writer.buffers) {
              expect(BinaryData.isValidTcp(buffer), isTrue);
            }
          }
        });
      });

      test("UdpWriter, Send, Each chunk has valid packet type", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, false).then((int ms) {
          expectAsync1(ms) {
            for (var buffer in writer.buffers) {
              expect(BinaryData.getPacketType(buffer), equals(BINARY_TYPE_CUSTOM));
            }
          }
        });
      });

      test("UdpWriter, Send, Each chunk has header", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, false).then((int ms) {
          expectAsync1(ms) {
            for (var buffer in writer.buffers) {
              expect(BinaryData.hasHeader(buffer), isTrue);
            }
          }
        });
      });

      test("UdpWriter, Send, Each chunk has same signature", () {
        writer.send(buffer, BINARY_TYPE_CUSTOM, false).then((int ms) {
          expectAsync1(ms) {
            for (var buffer in writer.buffers) {
              expect(writer.buffers.every(
                  (b) => BinaryData.getSignature(b) == BinaryData.getSignature(writer.buffers[0])), isTrue);
            }
          }
        });
      });
    });
  }
}