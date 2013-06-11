part of rtc_client;

class SctpPeerConnection extends PeerConnection {
  RtcDataChannel _stringChannel;
  RtcDataChannel _byteChannel;
  RtcDataChannel _blobChannel;

  SctpPeerConnection(PeerManager pm, RtcPeerConnection p) : super(pm, p) {

  }

  void initChannel() {
    _stringChannel = createStringChannel(STRING_CHANNEL, {});
    _byteChannel = createByteBufferChannel(BYTE_CHANNEL, {});
    _blobChannel = createBlobChannel(BLOB_CHANNEL, {});
  }

  void close() {
    _stringChannel.close();
    _byteChannel.close();
    _blobChannel.close();
    super.close();
  }
  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    super._onNewDataChannelOpen(e);
    var channel = e.channel;

    if (channel.label == BYTE_CHANNEL)
      _byteChannel = channel;
    else if (channel.label == BLOB_CHANNEL)
      _blobChannel = channel;
    else
      _stringChannel = channel;
  }
}