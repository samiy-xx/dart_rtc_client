part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {

  TCPDataWriter() : super(BINARY_PROTOCOL_TCP) {

  }

  Future<bool>  send(ArrayBuffer buffer, int packetType) {
    Completer completer = new Completer();
    return completer.future;
  }
}

