part of rtc_client;

abstract class BinaryDataReader extends GenericEventTarget<BinaryDataEventListener>{
  PeerConnection _peer;
  RtcDataChannel _channel;

  set dataChannel(RtcDataChannel c) => setChannel(c);
  set fileAsBuffer(bool v);
  BinaryDataReader(PeerConnection wrapper) : super() {
    _peer = wrapper;
  }

  void setChannel(RtcDataChannel c) {
    _channel = c;
    _channel.onMessage.listen(_onChannelMessage);
  }

  void _onChannelMessage(MessageEvent e) {
    if (e.data is Blob) {
      throw new NotImplementedException("Blob is not implemented");
    }

    else if (e.data is ByteBuffer) {
      readChunk(e.data);
    }

    else if (e.data is ByteData) {
      readChunk((e.data as ByteData).buffer);
    }

    else {
        Future f = readChunkString(e.data);
    }
  }

  Future readChunkString(String s);
  void readChunk(ByteBuffer buffer);
}