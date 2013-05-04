part of rtc_client_tests;

class TcpReaderTests implements BinaryDataReceivedEventListener {

  final String testString = "0123456789";
  TCPDataReader reader;
  ByteBuffer result;
  String longTestString;
  ByteBuffer buffer;

  const int CHUNK_SIZE = 50;
  const int STRING_LENGTH = 1000;

  run() {
    group('TcpReaderTests', () {

      setUp(() {
        longTestString = "0987654321"+ TestUtils.genRandomString(STRING_LENGTH) + "1234567890";
        buffer = BinaryData.bufferFromString(testString);
        reader = new TCPDataReader(null);
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



  void onPeerString(PeerWrapper pw, String s) {}
  void onPeerBuffer(PeerWrapper pw, ByteBuffer b) {
    result = b;
  }
  void onPeerFile(PeerWrapper pw, Blob b) {}
  void onPeerReadChunk(PeerWrapper pw, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {}

  void onPeerSendSuccess(int signature, int sequence) {}
}



