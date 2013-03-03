part of rtc_client;

/**
 * DataChannel enabled peer connection
 */
class DataPeerWrapper extends PeerWrapper implements BinaryDataReceivedEventListener, BinaryDataSentEventListener {
  /* DataChannel */
  RtcDataChannel _dataChannel;

  /* Logger */
  Logger _log = new Logger();

  /* Current channel state */
  String _channelState = null;


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
    _peer.onStateChange.listen(_onStateChanged);


  }

  void _onStateChanged(Event e) {
    if (_peer.readyState == PEER_STABLE) {
      //initChannel();
    }
  }

  void setAsHost(bool value) {
    super.setAsHost(value);

    _log.Debug("(datapeerwrapper.dart) Initializing datachannel now");
    initChannel();
  }

  void initialize() {
    if (_isHost) {
      _log.Debug("Is Host");

      _sendOffer();
    }

  }

  /**
   * Created the data channel
   * TODO: Whenever these reliable and unreliable are implemented by whomever. fix this.
   */
  void initChannel() {
    new Logger().Debug("Initializing send data channel");
    _dataChannel = _peer.createDataChannel("channel", {'reliable': _isReliable});
    _dataChannel.binaryType = "arraybuffer";
    _dataChannel.onClose.listen(onDataChannelClose);
    _dataChannel.onOpen.listen(onDataChannelOpen);
    _dataChannel.onError.listen(onDataChannelError);

    _binaryWriter = new BinaryDataWriter(_dataChannel);
    _binaryWriter.subscribe(this);

    _binaryReader = new BinaryDataReader(_dataChannel);
    _binaryReader.subscribe(this);
  }

  /**
   * Callback for when data channel created by the other party comes trough the peer
   */
  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    new Logger().Debug("--- Receiving incoming data channel");;

    _dataChannel = e.channel;
    _dataChannel.onClose.listen(onDataChannelClose);
    _dataChannel.onOpen.listen(onDataChannelOpen);
    _dataChannel.onError.listen(onDataChannelError);

    _binaryWriter = new BinaryDataWriter(_dataChannel);
    _binaryWriter.subscribe(this);

    _binaryReader = new BinaryDataReader(_dataChannel);
    _binaryReader.subscribe(this);

  }

  /**
   * Sends a packet trough the data channel
   */
  void send(Packet p) {
    String packet = PacketFactory.get(p);
    //_dataChannel.send(packet);
  }

  /**
   * Send blob
   */
  void sendBlob(Blob b) {
    //_dataChannel.send(b);
  }

  void sendBuffer(ArrayBuffer buf, int packetType) {
    new Logger().Debug("(datapeerwrapper.dart) sending arraybuffer");
    _binaryWriter.send(buf, packetType);
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
    //_binaryWriter.rewrite(signature, sequence);
  }

  void onLocalRequestResend(int signature, int sequence) {
    //_binaryWriter.rewrite(signature, sequence);
  }
  /**
   * Implements BinaryDataReceivedEventListener onReadChunk
   */
  void onReadChunk(ArrayBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesLeft) {
    new Logger().Debug("(datapeerwrapper.dart) received chunk $signature $sequence $totalSequences $bytes $bytesLeft");
    //_binaryWriter.removeFromBuffer(signature, sequence);

   _binaryWriter.writeAck(signature, sequence, true);
  }

  void onSendSuccess(int signature, int sequence) {
    //new Logger().Debug("Received ack for $signature $sequence");
    _binaryWriter.removeFromBuffer(signature, sequence);
  }

  /**
   * Implements BinaryDataReceivedEventListener onWriteChunk
   */
  void onWriteChunk(int signature, int sequence, int totalSequences, int bytes, int bytesLeft) {

  }


  /**
   * Data channel is open and ready for data
   */
  void onDataChannelOpen(Event e) {
    RtcDataChannel dc = e.target;
    _signalStateChanged();
    _log.Debug("(datapeerwrapper.dart) DataChannelOpen ${dc.label}");
  }

  /**
   * Ugh
   */
  void onDataChannelClose(Event e) {
    RtcDataChannel dc = e.target;
    _signalStateChanged();
    _log.Debug("(datapeerwrapper.dart) DataChannelClose ${dc.label}");
  }

  /**
   * Message, check if blob, otherwise assume string data
   */
  void onDataChannelMessage(MessageEvent e) {
    new Logger().Debug("datachannel message");

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

    if (_dataChannel.readyState != _channelState) {
      listeners.where((l) => l is PeerDataEventListener).forEach((PeerDataEventListener l) {
        l.onChannelStateChanged(this, _dataChannel.readyState);
      });
      _channelState = _dataChannel.readyState;
    }
  }
}
