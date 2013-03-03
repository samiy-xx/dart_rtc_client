part of rtc_client;

class TCPDataWriter extends BinaryDataWriter {
  TCPDataWriter(RtcDataChannel c) : super(c) {
    _binaryProtocol = BINARY_PROTOCOL_TCP;
  }
}

