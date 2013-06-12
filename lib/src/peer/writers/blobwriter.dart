part of rtc_client;

class BlobWriter extends GenericEventTarget<BinaryDataEventListener>{
  static final _logger = new Logger("dart_rtc_client.BlobWriter");
  static const int MAX_CHUNK_SIZE = 1024 * 50;
  final PeerConnection _peerConnection;
  RtcDataChannel _channel;
  int get buffered => _channel.bufferedAmount;

  BlobWriter(PeerConnection pc) : _peerConnection = pc {

  }

  void setChannel(RtcDataChannel c) {
    _channel = c;
  }

  Future<int> sendFile(Blob b) {
    _logger.fine("Sending blob of ${b.size} bytes");
    Completer<int> c = new Completer<int>();

    int left_to_send = b.size;
    int read = 0;


    new Timer.periodic(const Duration(milliseconds: 1), (Timer t) {
      if (buffered > 0)
        return;

      int size_to_send = left_to_send > MAX_CHUNK_SIZE ? MAX_CHUNK_SIZE : left_to_send;
      Blob toSend = b.slice(read, read + size_to_send);

      read += size_to_send;
      left_to_send -= size_to_send;
      _signalWriteChunk(0, 0, 0, toSend.size);
      write(toSend);
      _signalWroteChunk(0, 0, 0, toSend.size);
      if (left_to_send == 0) {
        t.cancel();
        c.complete(1);
      }
    });

    return c.future;
  }

  void write(Blob b) {
    _channel.send(b);
  }
  void _signalWriteChunk(int signature, int sequence, int totalSequences, int bytes) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWriteChunk(_peerConnection, signature, sequence, totalSequences, bytes);
      });
    });
  }

  void _signalWroteChunk(int signature, int sequence, int totalSequences, int bytes) {
    window.setImmediate(() {
      listeners.where((l) => l is BinaryDataSentEventListener).forEach((BinaryDataSentEventListener l) {
        l.onWroteChunk(_peerConnection, signature, sequence, totalSequences, bytes);
      });
    });
  }
}