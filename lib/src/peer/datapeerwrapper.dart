part of rtc_client;

/**
 * DataChannel enabled peer connection
 */
class DataPeerWrapper extends PeerWrapper implements BinaryDataReceivedEventListener, BinaryDataSentEventListener {
  /* DataChannel */
  RtcDataChannel _sendDataChannel;
  RtcDataChannel _recvDataChannel;

  /* Logger */
  Logger _log = new Logger();

  /* Current channel state */
  String _sendChannelState = null;
  String _recvChannelState = null;

  /* reliable tcp, unreliable udp */
  bool _isReliable = false;

  /** Set reliable */
  set isReliable(bool r) => _isReliable = r;

  BinaryDataWriter _binaryWriter;
  BinaryDataReader _binaryReader;

  /**
   * Constructor
   */
  DataPeerWrapper(PeerManager pm, RtcPeerConnection p) : super(pm, p) {
    _peer.onDataChannel.listen(_onNewDataChannelOpen);
  }

  void setAsHost(bool value) {
    super.setAsHost(value);

    _log.Debug("(datapeerwrapper.dart) Initializing datachannel now");
    initChannel();
  }

  void initialize() {
    if (_isHost) {
      _log.Debug("Is Host");
      initChannel();
      _sendOffer();
    }
  }

  /**
   * Created the data channel
   * TODO: Whenever these reliable and unreliable are implemented by whomever. fix this.
   */
  void initChannel() {
    _sendDataChannel = _peer.createDataChannel("send", {'reliable': _isReliable});
    _sendDataChannel.binaryType = "arraybuffer";
    _sendDataChannel.onClose.listen(onDataChannelClose);
    _sendDataChannel.onOpen.listen(onDataChannelOpen);
    _sendDataChannel.onError.listen(onDataChannelError);

    //_recvDataChannel = _peer.createDataChannel("recv", {'reliable': _isReliable});
    //_recvDataChannel.binaryType = "arraybuffer";
    //_recvDataChannel.onClose.listen(onDataChannelClose);
    //_recvDataChannel.onOpen.listen(onDataChannelOpen);
    //_recvDataChannel.onError.listen(onDataChannelError);
    //_recvDataChannel.onMessage.listen(onDataChannelMessage);

    _binaryWriter = new BinaryDataWriter(_sendDataChannel);
    _binaryWriter.subscribe(this);

    _binaryReader = new BinaryDataReader(_sendDataChannel);
    _binaryReader.subscribe(this);
  }

  /**
   * Sends a packet trough the data channel
   */
  void send(Packet p) {
    String packet = PacketFactory.get(p);
    _sendDataChannel.send(packet);
  }

  /**
   * Send blob
   */
  void sendBlob(Blob b) {
    _sendDataChannel.send(b);
  }

  void sendBuffer(ArrayBuffer buf, int packetType) {
    new Logger().Debug("(datapeerwrapper.dart) sending arraybuffer");
    _binaryWriter.write(buf, packetType, true);
  }

  Future<int> sendBufferAsync(ArrayBuffer buf, int packetType) {
    return _binaryWriter.writeAsync(buf, packetType, true);
  }

  /**
   * Implements BinaryDataReceivedEventListener onPacket
   */
  void onPacket(Packet p) {
    print ("got packet ${p.packetType.toString()}");
  }

  /**
   * Implements BinaryDataReceivedEventListener onString
   */
  void onString(String s) {
    print("got string $s");
  }

  /**
   * Implements BinaryDataReceivedEventListener onBuffer
   */
  void onBuffer(ArrayBuffer b) {
    print("got buffer, length ${b.byteLength}");
  }
  /**
   * Implements BinaryDataReceivedEventListener onRequestResend
   */
  void onRemoteRequestResend(int signature, int sequence) {
    _binaryWriter.rewrite(signature, sequence);
  }
  void onLocalRequestResend(int signature, int sequence) {
    _binaryWriter.rewrite(signature, sequence);
  }
  /**
   * Implements BinaryDataReceivedEventListener onReadChunk
   */
  void onReadChunk(ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesLeft) {
    print("received chunk $signature $sequence $totalSequences $bytes $bytesLeft");
    //_binaryWriter.removeFromBuffer(signature, sequence);
    // this wont work, chrome crashes if send and receive at the same time
    _binaryWriter.writeAck(buffer, true);
  }

  /**
   * Implements BinaryDataReceivedEventListener onWriteChunk
   */
  void onWriteChunk(int signature, int sequence, int totalSequences, int bytes, int bytesLeft) {

  }

  /**
   * Callback for when data channel created by the other party comes trough the peer
   */
  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    new Logger().Debug("onDataChannelOpen");
    //if (e.channel.label == "send") {
    //  new Logger().Debug("label is send, setting to receive");
    //  _recvDataChannel = e.channel;
    //  _recvDataChannel.onClose.listen(onDataChannelClose);
    //  _recvDataChannel.onOpen.listen(onDataChannelOpen);
    //  _recvDataChannel.onError.listen(onDataChannelError);
    //  //_binaryReader = new BinaryDataReader(_recvDataChannel);
    //  //_binaryReader.subscribe(this);
    //  _recvDataChannel.onMessage.listen(onDataChannelMessage);
    //} else {
    //  new Logger().Debug("label is ${e.channel.label} , setting to send");
      _sendDataChannel = e.channel;
      _sendDataChannel.onClose.listen(onDataChannelClose);
      _sendDataChannel.onOpen.listen(onDataChannelOpen);
      _sendDataChannel.onError.listen(onDataChannelError);
      _binaryWriter = new BinaryDataWriter(_sendDataChannel);
      _binaryWriter.subscribe(this);
      _binaryReader = new BinaryDataReader(_sendDataChannel);
      _binaryReader.subscribe(this);
    //}
  }

  /**
   * Data channel is open and ready for data
   */
  void onDataChannelOpen(Event e) {
    _signalStateChanged();
    _log.Debug("(datapeerwrapper.dart) DataChannelOpen");
  }

  /**
   * Ugh
   */
  void onDataChannelClose(Event e) {
    _signalStateChanged();
    _log.Debug("(datapeerwrapper.dart) DataChannelClose");
  }

  /**
   * Message, check if blob, otherwise assume string data
   */
  void onDataChannelMessage(MessageEvent e) {
    new Logger().Debug("datachannel message");
    /*if (e.data is Blob) {
      _log.Debug("Received Blob");
      throw new NotImplementedException("Blob is not implemented");
    } else if (e.data is ArrayBuffer || e.data is ArrayBufferView) {
      _log.Debug("Received ArrayBuffer ${e.data.runtimeType.toString()}");
      throw new NotImplementedException("ArrayBuffer is not implemented");
    } else {
      _binaryReader.readChunkString(e.data);
      _log.Debug("Received Text");
      try {
        Packet p = PacketFactory.getPacketFromString(e.data);
        if (p != null) {
          _signalPacketArrived(p);
        }
      } catch(e) {}

    }*/
  }

  /**
   * Error
   */
  void onDataChannelError(RtcDataChannelEvent e) {
    _log.Debug("(datapeerwrapper.dart) DataChannelError $e");
  }

  /**
   * Signal listeners that packet has arrived
   */
  void _signalPacketArrived(Packet p) {
    listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
      l.onPacket(this, p);
    });
  }

  /**
   * signal listeners that channel state has changed
   */
  void _signalStateChanged() {

    if (_sendDataChannel.readyState != _sendChannelState) {
      listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
        l.onChannelStateChanged(this, _sendDataChannel.readyState);
      });
      _sendChannelState = _sendDataChannel.readyState;
    }
  }
}
