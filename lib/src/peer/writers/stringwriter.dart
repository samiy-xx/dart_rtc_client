part of rtc_client;

class StringWriter extends DataWriter {
  static final _logger = new Logger("dart_rtc_client.StringWriter");
  final PeerConnection _peerConnection;
  RtcDataChannel _channel;


  StringWriter(PeerConnection pc) : _peerConnection = pc {
  }

  void setChannel(RtcDataChannel c) {
    _channel = c;
  }

  Future<int> send(String s) {
    _logger.fine("Sending string of ${s.length} bytes");
    Completer<int> c = new Completer<int>();
    window.setImmediate(() {
      _channel.send(s);
      c.complete(1);
    });
    return c.future;
  }
}