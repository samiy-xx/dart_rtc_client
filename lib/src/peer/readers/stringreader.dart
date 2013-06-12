part of rtc_client;

class StringReader extends GenericEventTarget<BinaryDataEventListener> {
  static final _logger = new Logger("dart_rtc_client.StringReader");
  final PeerConnection _peerConnection;
  RtcDataChannel _channel;

  StringReader(PeerConnection pc) : _peerConnection = pc {

  }

  void setChannel(RtcDataChannel c) {
    _channel = c;
    _channel.onMessage.listen(_onMessage);
  }

  void _onMessage(MessageEvent e) {
    if (e.data is! String)
      throw new Exception("Wrong data type");

    _readString(e.data);
  }

  void _readString(String s) {
    _signalReadString(s);
  }

  void _signalReadString(String s) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
        l.onPeerString(_peerConnection, s);
      });
    });
  }
}