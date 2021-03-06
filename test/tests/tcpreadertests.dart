part of rtc_client_tests;

class TcpReaderTests implements BinaryDataReceivedEventListener {

  final String testString = "0123456789";
  MockTcpWriter writer;
  MockTcpReader reader;
  ByteBuffer result;
  String longTestString;
  ByteBuffer buffer;

  static const int CHUNK_SIZE = 50;
  static const int STRING_LENGTH = 6000;

  run() {
    group('TcpReaderTests', () {

      setUp(() {
        longTestString = "0987654321"+ TestUtils.genRandomString(STRING_LENGTH) + "1234567890";
        buffer = BinaryData.bufferFromString(testString);
        reader = new MockTcpReader();
        writer = new MockTcpWriter(reader);
        reader.subscribe(this);
      });

      tearDown(() {

      });

      test("BinaryDataReader, readChunk, can read a chunk", () {

         ByteBuffer buffer = BinaryData.writeTcpHeader(BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, 1, 10);
         String t = BinaryData.stringFromBuffer(buffer);
         reader.readChunkString(t).then((a) {
           expectAsync1(a) {
             print("ASYNC");
             expect(result.lengthInBytes, equals(buffer.lengthInBytes - SIZEOF_TCP_HEADER));
             String out = BinaryData.stringFromBuffer(new Uint8List.view(result, 0, 9).buffer);
             expect(out, equals(testString));
           }
         });

      });
    });
  }



  void onPeerString(PeerConnection pc, String s) {}
  void onPeerBuffer(PeerConnection pc, ByteBuffer b, int type) {
    result = b;
  }
  void onPeerFile(PeerConnection pc, Blob b) {}
  void onPeerReadTcpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int bytes, int bytesTotal) {}
  void onPeerReadUdpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {}
  void onPeerSendSuccess(int signature, int sequence) {}
}



