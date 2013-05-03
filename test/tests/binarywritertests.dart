part of rtc_client_tests;

class BinaryWriterTests {
  String packetId;
  Packet defaultPacket;
  BinaryDataWriter writer;

  final int STRING_HEADER_BYTES = 4;
  final int PACKET_HEADER_BYTES = 3;
  final int FILE_HEADER_BYTES = 6;

  run() {
    group('BinaryWriterTests', () {

      setUp(() {
        defaultPacket = new ByePacket.With(packetId);
        //writer = new BinaryDataWriter();
      });

      tearDown(() {
        defaultPacket = null;
        //writer = null;
      });

    });
  }


}

