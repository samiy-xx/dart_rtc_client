part of rtc_client;

class TCPDataReader extends BinaryDataReader {
  TCPDataReader() : super() {

  }

  Future readChunkString(String s) {
    Completer c = new Completer();
    window.setImmediate(() {
      readChunk(BinaryData.bufferFromString(s));
      c.complete();
    });
    return c.future;
  }

  void readChunk(ArrayBuffer buffer) {
    
  }
}

