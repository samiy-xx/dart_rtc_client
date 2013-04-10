part of rtc_client_tests;

class UDPReaderTests implements BinaryDataReceivedEventListener {
  final int HEADER_SIZE = 16;
  final String testString = "0123456789";
  UDPDataReader reader;
  ArrayBuffer result;
  
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
         ArrayBuffer buffer = BinaryData.writeUdpHeader(BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, 1, 1, 1, 10);
         reader.readChunk(buffer);
         expect(result.byteLength, equals(buffer.byteLength - HEADER_SIZE));
         String out = BinaryData.stringFromBuffer(result.slice(0, 19));
         print(out);
         expect(out, equals(testString));
         
      });
    });
  }
  
 
  
  void onPeerString(PeerWrapper pw, String s) {}
  void onPeerBuffer(PeerWrapper pw, ArrayBuffer b) {
    result = b;
  }
  void onPeerFile(PeerWrapper pw, Blob b) {}
  void onPeerReadChunk(PeerWrapper pw, ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {}

  void onPeerSendSuccess(int signature, int sequence) {}
}



 