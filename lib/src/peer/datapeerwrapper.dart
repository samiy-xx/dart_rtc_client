part of rtc_client;

/**
 * DataChannel enabled peer connection
 */
class DataPeerWrapper extends PeerWrapper implements BinaryDataReceivedEventListener, BinaryDataSentEventListener {
  RtcDataChannel _dataChannel;
  static final _logger = new Logger("dart_rtc_client.DataPeerWrapper");
  String _channelState = null;

  /* reliable tcp, unreliable udp */
  bool _isReliable = false;

  /** Set reliable */
  set isReliable(bool r) => _isReliable = r;

  BinaryDataWriter _binaryWriter;
  BinaryDataReader _binaryReader;

  BinaryDataWriter get binaryWriter => _binaryWriter;
  BinaryDataReader get binaryReader => _binaryReader;

  DataPeerWrapper(PeerManager pm, RtcPeerConnection p) : super(pm, p) {
    _peer.onDataChannel.listen(_onNewDataChannelOpen);
    _peer.on['onsignalingstatechange'].listen(_onStateChanged);
    _binaryWriter = new UDPDataWriter(this);
    _binaryReader = new UDPDataReader(this);

    _binaryWriter.subscribe(this);
    _binaryReader.subscribe(this);
  }

  void subscribeToBinaryEvents(BinaryDataEventListener l) {
    _binaryWriter.subscribe(l);
  }

  void _onStateChanged(Event e) {
    if (_peer.signalingState == PEER_STABLE) {
      //initChannel();
    }
  }

  void setAsHost(bool value) {
    super.setAsHost(value);

    _logger.fine("Initializing datachannel now");
    initChannel();
  }

  void initialize() {
    if (_isHost) {
      _logger.fine("Is Host");
      _sendOffer();
    }
  }

  /**
   * Created the data channel
   * TODO: Whenever these reliable and unreliable are implemented by whomever. fix this.
   */
  void initChannel() {
    _logger.fine("Initializing send data channel");
    try {
      _dataChannel = _peer.createDataChannel("channel", {'reliable': _isReliable});
      _dataChannel.binaryType = "arraybuffer";
      _dataChannel.onClose.listen(onDataChannelClose);
      _dataChannel.onOpen.listen(onDataChannelOpen);
      _dataChannel.onError.listen(onDataChannelError);

      _binaryWriter.dataChannel = _dataChannel;
      _binaryReader.dataChannel = _dataChannel;
    } on Exception catch(e, s) {
      _logger.severe("$e");
      _logger.fine("$s");
    }
  }

  /**
   * Callback for when data channel created by the other party comes trough the peer
   */
  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    _logger.fine("--- Receiving incoming data channel");;

    _dataChannel = e.channel;
    _dataChannel.onClose.listen(onDataChannelClose);
    _dataChannel.onOpen.listen(onDataChannelOpen);
    _dataChannel.onError.listen(onDataChannelError);

    _binaryWriter.dataChannel = _dataChannel;
    _binaryReader.dataChannel = _dataChannel;
  }

  void sendString(String s) {
    _dataChannel.send(s);
  }

  /**
   * Send blob
   */
  void sendBlob(Blob b) {
    throw new NotImplementedException("Sending blob is not implemented");
  }

  Future<int> sendFile(File f) {
    return _binaryWriter.sendFile(f);
    /*Completer<int> completer = new Completer<int>();
    FileReader reader = new FileReader();
    reader.onLoadEnd.listen((ProgressEvent e) {
      sendBuffer(reader.result, BINARY_TYPE_FILE, true).then((int i) {
        completer.complete(i);
      });
    });
    reader.readAsArrayBuffer(f);
    return completer.future;*/
  }

  Future<int> sendBuffer(ByteBuffer buf, int packetType, bool reliable) {
    return _binaryWriter.send(buf, packetType, reliable);
  }

  /**
   * Implements BinaryDataReceivedEventListener onString
   */
  void onPeerString(PeerWrapper pw, String s) {

  }

  /**
   * Implements BinaryDataReceivedEventListener onBuffer
   */
  void onPeerBuffer(PeerWrapper pw, ByteBuffer b) {

  }

  void onPeerFile(PeerWrapper pw, Blob b) {
    _logger.fine("got blob, ${b.size} bytes");
  }

  /**
   * Implements BinaryDataReceivedEventListener onReadChunk
   */
  void onPeerReadUdpChunk(PeerWrapper pw, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    //if (_binaryWriter is UDPDataWriter)
    //  (_binaryWriter as UDPDataWriter).writeAck(signature, sequence);
  }

  void onPeerReadTcpChunk(PeerWrapper pw, ByteBuffer buffer, int signature, int bytes, int bytesTotal) {

  }

  void onPeerSendSuccess(int signature, int sequence) {
    if (_binaryWriter is UDPDataWriter)
      (_binaryWriter as UDPDataWriter).receiveAck(signature, sequence);
  }

  /**
   * Implements BinaryDataSentEventListener onWriteChunk
   */
  void onWriteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes) {

  }

  /**
   * Implements BinaryDataSentEventListener onWroteChunk
   */
  void onWroteChunk(PeerWrapper pw, int signature, int sequence, int totalSequences, int bytes) {

  }

  /**
   * Data channel is open and ready for data
   */
  void onDataChannelOpen(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged();
    _logger.fine("DataChannelOpen ${dc.label}");
  }

  /**
   * Ugh
   */
  void onDataChannelClose(Event e) {
    RtcDataChannel dc = e.target;
    _signalChannelStateChanged();
    _logger.fine(" DataChannelClose ${dc.label}");
  }

  /**
   * Message, check if blob, otherwise assume string data
   */
  void onDataChannelMessage(MessageEvent e) {
    _logger.fine("datachannel message");

  }

  /**
   * Error
   */
  void onDataChannelError(RtcDataChannelEvent e) {
    _logger.fine("DataChannelError $e");
  }

  /**
   * Signal listeners that packet has arrived
   */
  //void _signalPacketArrived(Packet p) {
  //  listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
  //    l.onPacket(this, p);
  //  });
  //}

  /**
   * signal listeners that channel state has changed
   */
  void _signalChannelStateChanged() {

    if (_dataChannel.readyState != _channelState) {
      listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
        l.onChannelStateChanged(this, _dataChannel.readyState);
      });
      _channelState = _dataChannel.readyState;
    }
  }
}
