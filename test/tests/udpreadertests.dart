part of rtc_client_tests;

class UDPReaderTests implements BinaryDataReceivedEventListener {

  final String testString = "0123456789";
  UDPDataReader reader;
  ByteBuffer result;
  String longTestString;
  ByteBuffer buffer;
  int _start;
  const int CHUNK_SIZE = 50;
  const int STRING_LENGTH = 1000;

  run() {
    group('UdpReaderTests', () {

      setUp(() {
        longTestString = "0987654321"+ TestUtils.genRandomString(STRING_LENGTH) + "1234567890";
        buffer = BinaryData.bufferFromString(testString);
        reader = new UDPDataReader(null);
        reader.subscribe(this);
      });

      tearDown(() {

      });

      test("Test speed", () {
        var string = TestUtils.genRandomString(59999);
        print("String created ${string.length}");
        var buf = BinaryData.bufferFromString(string);
        print("buffer created ${buf.lengthInBytes}");
        _start = new DateTime.now().millisecondsSinceEpoch;
        send(buf);
      });

      test("BinaryDataReader, readChunk, can read a chunk", () {

         ByteBuffer buffer = BinaryData.writeUdpHeader(BinaryData.bufferFromString(testString), BINARY_TYPE_CUSTOM, 1, 1, 1, 10);
         String t = BinaryData.stringFromBuffer(buffer);
         reader.readChunkString(t).then((a) {
           expectAsync1(a) {
             expect(result.lengthInBytes, equals(buffer.lengthInBytes - SIZEOF_UDP_HEADER));
             String out = BinaryData.stringFromBuffer(new Uint8List.view(result, 0, 9).buffer);
             expect(out, equals(testString));
           }
         });

      });
    });
  }

  int chunks = 0;

  void onPeerString(PeerConnection pc, String s) {}
  void onPeerBuffer(PeerConnection pc, ByteBuffer b,int binaryType) {

    //print("Got buffer of size ${b.lengthInBytes} in ${_now - _start} milliseconds");
    result = b;
  }
  void onPeerFile(PeerConnection pc, Blob b) {}
  void onPeerReadTcpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int bytes, int bytesTotal) {}
  void onPeerReadUdpChunk(PeerConnection pc, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    chunks++;
    //print(chunks);
    if (chunks == 76) {
      int _now = new DateTime.now().millisecondsSinceEpoch;
      print("read chunk ${_now - _start}");
    }

  }

  void onPeerSendSuccess(int signature, int sequence) {}

  void send(ByteBuffer buffer) {
    int totalSequences = (buffer.lengthInBytes ~/ 800) + 1;
    int sequence = 1;
    int read = 0;
    int leftToRead = buffer.lengthInBytes;
    int signature = new Random().nextInt(100000000);
    print("creating $totalSequences sequences");
    while (read < buffer.lengthInBytes) {
      int toRead = leftToRead > 800 ? 800 : leftToRead;
      ByteBuffer toAdd = new Uint8List.fromList(new Uint8List.view(buffer).sublist(read, read+toRead));
      ByteBuffer b = addUdpHeader(
          //buffer.slice(read, read + toRead),
          toAdd,
          BINARY_TYPE_CUSTOM,
          sequence,
          totalSequences,
          signature,
          buffer.lengthInBytes
      );
      reader.readChunkString(BinaryData.stringFromBuffer(b));
      //addSequence(signature, sequence, totalSequences, b, reliable);
      sequence++;
      read += toRead;
      leftToRead -= toRead;
    }
    print("all sent");
  }

  ByteBuffer addUdpHeader(ByteBuffer buf, int packetType, int sequenceNumber, int totalSequences, int signature, int total) {
    return BinaryData.writeUdpHeader(buf, packetType, sequenceNumber, totalSequences, signature, total);
  }


}



