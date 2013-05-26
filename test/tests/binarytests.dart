part of rtc_client_tests;

class BinaryTests {
  const String testString = "this is a string for test";
  const int defaultSignature = 1337;
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


      test("BinaryData, hasHeader, retuns true if header is present", () {
        ByteBuffer udpBuffer = getSimpleUdpPacket();
        expect(BinaryData.hasHeader(udpBuffer), isTrue);

        ByteBuffer tcpBuffer = getSimpleTcpPacket();
        expect(BinaryData.hasHeader(tcpBuffer), isTrue);
      });

      test("BinaryData, isCommand, retuns true if data is command", () {
        ByteBuffer ack = BinaryData.createAck(10, [10]);
        expect(BinaryData.isCommand(ack), isTrue);

        ByteBuffer nonAck = getSimpleUdpPacket();
        expect(BinaryData.isCommand(nonAck), isFalse);
      });

      /*test("BinaryData, getCommand, returns command type integer", () {
        ByteBuffer ack = BinaryData.createAck(10, [10]);
        expect(BinaryData.getCommand(ack), equals(BINARY_PACKET_ACK));
      });*/

      test("BinaryData, getSignature, returns signature", () {
        ByteBuffer udpBuffer = getSimpleUdpPacket();

        expect(BinaryData.isValidUdp(udpBuffer), isTrue);

        expect(BinaryData.getSignature(udpBuffer), equals(defaultSignature));

        //ByteBuffer tcpBuffer = getSimpleTcpPacket();
        //expect(BinaryData.getSignature(tcpBuffer), equals(defaultSignature));
      });

      test("BinaryData, getSequenceNumber, returns sequence number", () {
        ByteBuffer udpBuffer = getSimpleUdpPacket();
        expect(BinaryData.getSequenceNumber(udpBuffer), equals(1));

        //ByteBuffer tcpBuffer = getSimpleTcpPacket();
        //expect(BinaryData.getSequenceNumber(tcpBuffer), equals(0));
      });

      test("BinaryData, getPacketType, returns the packet type integer", () {
        ByteBuffer udpBuffer = getSimpleUdpPacket();
        expect(BinaryData.getPacketType(udpBuffer), equals(BINARY_TYPE_CUSTOM));

        ByteBuffer tcpBuffer = getSimpleTcpPacket();
        expect(BinaryData.getPacketType(tcpBuffer), equals(BINARY_TYPE_CUSTOM));
      });
    });
  }

  ByteBuffer getSimpleTcpPacket() {
    return BinaryData.writeTcpHeader(
        BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, defaultSignature, testString.length + SIZEOF_TCP_HEADER);
  }

  ByteBuffer getSimpleUdpPacket() {
    return BinaryData.writeUdpHeader
        (BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, 1, 1, defaultSignature,  testString.length + SIZEOF_UDP_HEADER);
  }
}

