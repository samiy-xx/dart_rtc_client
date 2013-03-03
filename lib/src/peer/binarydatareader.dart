part of rtc_client;

abstract class BinaryDataReader extends GenericEventTarget<BinaryDataEventListener>{
  RtcDataChannel _channel;

  BinaryDataReader(RtcDataChannel c) : super() {
    _channel = c;
    _channel.onMessage.listen(_onChannelMessage);
  }

  void _onChannelMessage(MessageEvent e) {
    if (e.data is Blob) {
      throw new NotImplementedException("Blob is not implemented");
    }

    else if (e.data is ArrayBuffer) {
      readChunk(e.data);
    }

    else if (e.data is ArrayBufferView) {
      readChunk((e.data as ArrayBufferView).buffer);
    }

    else {
      readChunkString(e.data);
    }
  }

  void readChunkString(String s);
  void readChunk(ArrayBuffer buffer);
}