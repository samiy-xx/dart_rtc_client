part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  TCPDataWriter(PeerWrapper wrapper) : super(BINARY_PROTOCOL_TCP, wrapper) {

  }

  Future<int>  send(ArrayBuffer buffer, int packetType, bool reliable) {
    Completer completer = new Completer();
    return completer.future;
  }
}

