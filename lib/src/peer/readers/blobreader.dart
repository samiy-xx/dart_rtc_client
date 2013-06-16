part of rtc_client;

class BlobReader extends DataReader {
  static final _logger = new Logger("dart_rtc_client.BlobReader");
  final PeerConnection _peerConnection;
  RtcDataChannel _channel;

  BlobReader(PeerConnection pc) : _peerConnection = pc {

  }

  void setChannel(RtcDataChannel c) {
    _channel = c;
    _channel.onMessage.listen(_onMessage);
  }

  void _onMessage(MessageEvent e) {
    if (e.data is! Blob)
      throw new Exception("Wrong data type");

    _readBlob(e.data);
  }

  void _readBlob(Blob blob) {
    _signalReadBlobChunk(blob);
  }

  void _signalReadBlobChunk(Blob blob) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataReceivedEventListener).forEach((BinaryDataReceivedEventListener l) {
        l.onPeerBlobChunk(_peerConnection, blob);
      });
    });
  }
}