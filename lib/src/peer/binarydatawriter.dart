part of rtc_client;

abstract class BinaryDataWriter extends GenericEventTarget<BinaryDataEventListener> {
  RtcDataChannel _channel;

  BinaryDataWriter(RtcDataChannel c) : super() {
    _channel = c;
  }

  void send(ArrayBuffer buffer, int packetType);
}

