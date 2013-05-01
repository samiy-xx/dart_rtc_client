part of rtc_client_tests;

class BinaryTests {
  run() {
    group('BinaryTests', () {
      setUp(() {

      });

      tearDown(() {

      });

      test("BinaryData, Converter, can create byte buffer from string", () {
        String testString = "this is a string";
        ByteBuffer result = BinaryData.bufferFromString(testString);
        expect(result.lengthInBytes, equals(testString.length));
      });

      test("BinaryData, Converter, can create string from buffer", () {
        String testString = "this is a string";
        ByteBuffer result = BinaryData.bufferFromString(testString);
        expect(result.lengthInBytes, equals(testString.length));
        String reCreated = BinaryData.stringFromBuffer(result);
        expect(reCreated, equals(testString));
      });

      test("BinaryData, writeTcpHeader, writes tcp headers", () {
        ByteBuffer buffer = BinaryData.bufferFromString("test");
        ByteBuffer tcpBuffer = BinaryData.writeTcpHeader(buffer, 1, 1, 1);
        expect(tcpBuffer, isNotNull);
        expect(tcpBuffer.lengthInBytes, equals(buffer.lengthInBytes + SIZEOF_TCP_HEADER));
      });

      test("BinaryData, writeUdpHeader, writes Udp headers", () {
        ByteBuffer buffer = BinaryData.bufferFromString("test");
        ByteBuffer tcpBuffer = BinaryData.writeUdpHeader(buffer, 1, 1, 1, 1, buffer.lengthInBytes);
        expect(tcpBuffer, isNotNull);
        expect(tcpBuffer.lengthInBytes, equals(buffer.lengthInBytes + SIZEOF_UDP_HEADER));
      });

      test("BinaryData, Validate, returns true for valid packet", () {
        ByteBuffer buffer = BinaryData.bufferFromString("test");

        ByteBuffer tcpBuffer = BinaryData.writeTcpHeader(buffer, 1, 1, buffer.lengthInBytes);
        expect(BinaryData.isValidTcp(tcpBuffer), equals(true));
        expect(BinaryData.isValidUdp(tcpBuffer), equals(false));

        ByteBuffer udpBuffer = BinaryData.writeUdpHeader(buffer, 1, 1, 1, 1, buffer.lengthInBytes);
        expect(BinaryData.isValidUdp(udpBuffer), equals(true));
      });
    });
  }
}

