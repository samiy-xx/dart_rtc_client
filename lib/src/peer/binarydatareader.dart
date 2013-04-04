part of rtc_client;

abstract class BinaryDataReader extends GenericEventTarget<BinaryDataEventListener>{
  PeerWrapper _wrapper;
  RtcDataChannel _channel;
  set dataChannel(RtcDataChannel c) => setChannel(c);

  BinaryDataReader(PeerWrapper wrapper) : super() {
    _wrapper = wrapper;
  }

  void setChannel(RtcDataChannel c) {
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
      Future f = readChunkString(e.data).then((_) {
        
      });
    }
  }

  Future readChunkString(String s);
  void readChunk(ArrayBuffer buffer);
}