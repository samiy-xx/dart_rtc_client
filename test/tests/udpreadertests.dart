part of rtc_client_tests;

class UDPReaderTests implements BinaryDataReceivedEventListener {

  final String testString = "0123456789";
  UDPDataReader reader;
  ByteBuffer result;

  run() {
    group('UdpReaderTests', () {

      setUp(() {
        reader = new UDPDataReader(null);
        reader.subscribe(this);
      });

      tearDown(() {

      });

      test("BinaryDataReader, readChunk, can read a chunk", () {
         //ArrayBuffer buffer = BinaryData.writeUdpHeader(genBufferOfSize(100), BINARY_TYPE_CUSTOM, 1, 1, 1, 100);
         ByteBuffer buffer = BinaryData.writeUdpHeader(BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, 1, 1, 1, 10);
         String t = BinaryData.stringFromBuffer(buffer);
         reader.readChunkString(t).then((a) {
           expect(result.lengthInBytes, equals(buffer.lengthInBytes - SIZEOF_UDP_HEADER));

           String out = BinaryData.stringFromBuffer(new Uint8List.view(result, 0, 9).buffer);
           //String out = BinaryData.stringFromBuffer(result.slice(0, 19));

           expect(out, equals(testString));
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



