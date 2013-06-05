part of rtc_client;

class PeerClientNew implements RtcClient, PeerConnectionEventListener, PeerMediaEventListener,
  PeerDataEventListener, BinaryDataReceivedEventListener, BinaryDataSentEventListener {

  static final _logger = new Logger("dart_rtc_client.PeerClient");

  Signaler _signalHandler;
  PeerManager _peerManager;
  MediaStream _ms = null;
  InitializationState _currentState;

  PeerManager get peerManager => _peerManager;
  Signaler get signalHandler =>_signalHandler;
  set signalHandler(Signaler s) => _signalHandler = s;

  VideoConstraints _getUserMediaConstraints;
  set getUserMediaConstraints(VideoConstraints vc) => _getUserMediaConstraints = vc;

  PeerConstraints _peerConstraints;
  set peerConstraints(PeerConstraints pc) => _peerConstraints = pc;

  StreamConstraints _streamConstraints;
  set streamConstraints(StreamConstraints sc) => _streamConstraints = sc;

  StreamController<MediaStreamAvailableEvent> _mediaStreamAvailableStreamController;
  Stream<MediaStreamAvailableEvent> get onRemoteMediaStreamAvailableEvent  => _mediaStreamAvailableStreamController.stream;

  StreamController<MediaStreamRemovedEvent> _mediaStreamRemovedStreamController;
  Stream<MediaStreamRemovedEvent> get onRemoteMediaStreamRemovedEvent  => _mediaStreamRemovedStreamController.stream;

  StreamController<InitializationStateEvent> _initializedController;
  Stream<InitializationStateEvent> get onInitializationStateChangeEvent => _initializedController.stream;

  StreamController<PeerStateChangedEvent> _peerStateChangeController;
  Stream<PeerStateChangedEvent> get onPeerStateChangeEvent => _peerStateChangeController.stream;

  StreamController<IceGatheringStateChangedEvent> _iceGatheringStateChangeController;
  Stream<IceGatheringStateChangedEvent> get onIceGatheringStateChangeEvent => _iceGatheringStateChangeController.stream;

  StreamController<DataChannelStateChangedEvent> _dataChannelStateChangeController;
  Stream<DataChannelStateChangedEvent> get onDataChannelStateChangeEvent => _dataChannelStateChangeController.stream;

  StreamController<RtcEvent> _binaryController;
  Stream<RtcEvent> get onBinaryEvent => _binaryController.stream;

  Stream<SignalingStateEvent> get onSignalingStateChanged => _signalHandler.onSignalingStateChanged;
  Stream<ServerEvent> get onServerEvent=> _signalHandler.onServerEvent;

  PeerClientNew(Signaler signaler) {
    _signalHandler = signaler;
    _peerManager = new PeerManager();
    _peerManager.subscribe(this);

    _createDefaultConstraints();
    _initializeControllers();

    onServerEvent.listen((ServerEvent e) => _serverEventHandler(e));
    onSignalingStateChanged.listen((SignalingStateEvent e) => _signalingEventHandler(e));
  }

  PeerClient setRequireAudio(bool b) {
    _getUserMediaConstraints.audio = b;
    return this;
  }

  PeerClient setRequireVideo(bool b) {
    _getUserMediaConstraints.video = b;
    return this;
  }

  PeerClient setRequireDataChannel(bool b) {
    _peerConstraints.dataChannelEnabled = b;
    _peerManager.dataChannelsEnabled = b;
    return this;
  }

  PeerClient setReliableDataChannel(bool b) {
    _peerManager.reliableDataChannels = b;
    return this;
  }

  void close() {
    _signalHandler.close();
    _peerManager.closeAll();
  }

  void sendString(String peerId, String message) {
    _getDataPeerWrapper(peerId).sendString(message);
  }

  void sendBlob(String peerId, Blob b) {
    return _getDataPeerWrapper(peerId).sendFile(b);
  }

  Future<int> sendFile(String peerId, File f) {
    return _getDataPeerWrapper(peerId).sendFile(f);
  }

  Future<int> sendArrayBufferReliable(String peerId, ByteBuffer data) {
      return _getDataPeerWrapper(peerId).sendBuffer(data, BINARY_TYPE_CUSTOM, true);
  }

  void sendArrayBufferUnReliable(String peerId, ByteBuffer data) {
    if (_peerManager.reliableDataChannels)
      throw new Exception("Can not send unreliable data with reliable channel");
    _getDataPeerWrapper(peerId).sendBuffer(data, BINARY_TYPE_CUSTOM, false);
  }

  void initialize() {
    if (!_getUserMediaConstraints.audio && !_getUserMediaConstraints.video && !_peerConstraints.dataChannelEnabled)
      throw new Exception("Must require either video, audio or data channel");

    if ((_getUserMediaConstraints.audio || _getUserMediaConstraints.video) && _ms == null) {
      if (MediaStream.supported) {
        window.navigator.getUserMedia(audio: _getUserMediaConstraints.audio, video: _getUserMediaConstraints.video).then((MediaStream stream) {
          _ms = stream;
          _peerManager.setLocalStream(stream);
          _signalHandler.initialize();
          _setState(InitializationState.MEDIA_READY);
          _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(stream, null, true));
        }).catchError((e) {
          _logger.severe("Error initializing $e");
          if (e is NavigatorUserMediaError) {
            window.alert("Unable to access user media. Is webcam or microphone used by another process?");
          }
        });
      } else {
        _setState(InitializationState.NOT_READY);
        return;
      }
    } else {
      _signalHandler.initialize();
    }

    window.onBeforeUnload.listen((_) {
      window.setImmediate(() {
        _signalHandler.close();
        _peerManager.closeAll();
      });
    });
  }

  void _initializeControllers() {
    _initializedController = new StreamController<InitializationStateEvent>();
    _mediaStreamAvailableStreamController = new StreamController();
    _mediaStreamRemovedStreamController = new StreamController();
    _peerStateChangeController = new StreamController();
    _iceGatheringStateChangeController = new StreamController();
    _dataChannelStateChangeController = new StreamController();
    _binaryController = new StreamController();
  }

  void _createDefaultConstraints() {
    _getUserMediaConstraints = new VideoConstraints();
    _peerConstraints = new PeerConstraints();
    _streamConstraints = new StreamConstraints();
  }

  PeerConnection _getPeerWrapper(String peerId) {
    PeerConnection w = _peerManager.findWrapper(peerId);
    if (w == null)
      throw new PeerWrapperNullException("Peer wrapper null: $peerId");
    return w;
  }

  PeerConnection _getDataPeerWrapper(String peerId) {

      PeerConnection w = _getPeerWrapper(peerId);

      return w;

  }

  void _setState(InitializationState state) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasListener)
      _initializedController.add(new InitializationStateEvent(state));
  }

  void _setStateWithChannelData(InitializationState state, ServerJoinEvent e) {
    if (_currentState == state)
      return;

    _currentState = state;

    if (_initializedController.hasListener)
      _initializedController.add(new ChannelInitializationStateEvent(state, e.channel, e.isOwner));
  }

  void _signalingEventHandler(SignalingStateEvent e) {
    if (e is SignalingReadyEvent) {
      SignalingReadyEvent p = e;

      _myId = p.id;
      if (_channelId != null)
        joinChannel(_channelId);
      _setState(InitializationState.REMOTE_READY);
    }
  }

  void _serverEventHandler(ServerEvent e) {
    if (e is ServerJoinEvent) {
      _setStateWithChannelData(InitializationState.CHANNEL_READY, e);
    }

    else if (e is ServerParticipantJoinEvent) {
    }

    else if (e is ServerParticipantIdEvent) {
    }

    else if (e is ServerParticipantLeftEvent) {

    }

    else if (e is ServerParticipantStatusEvent) {

    }

    else if (e is ServerChannelMessageEvent) {

    }
  }

  /**
   * Implements PeerDataEventListener onDateReceived
   * TODO : Do something with this
   */
  void onDataReceived(int buffered) {

  }

  /**
   * Implements PeerDataEventListener onChannelStateChanged
   */
  void onChannelStateChanged(PeerConnection p, String state){
    if (_dataChannelStateChangeController.hasListener)
      _dataChannelStateChangeController.add(new DataChannelStateChangedEvent(p, state));
  }

  /**
   * Remote media stream available from peer
   */
  void onRemoteMediaStreamAvailable(MediaStream ms, PeerConnection pw, bool main) {
   if (_mediaStreamAvailableStreamController.hasListener)
     _mediaStreamAvailableStreamController.add(new MediaStreamAvailableEvent(ms, pw));
  }

  /**
   * Media stream was removed
   */
  void onRemoteMediaStreamRemoved(PeerConnection pw) {
    if (_mediaStreamRemovedStreamController.hasListener)
      _mediaStreamRemovedStreamController.add(new MediaStreamRemovedEvent(pw));
  }

  /**
   * Implements PeerConnectionEventListener onPeerCreated
   */
  void onPeerCreated(PeerConnection pw) {

        pw.binaryReader.subscribe(this);
        pw.binaryWriter.subscribe(this);

      pw.subscribe(this);

  }

  /**
   * Implements PeerConnectionEventListener onPeerStateChanged
   */
  void onPeerStateChanged(PeerConnection pw, String state) {
    if (_peerStateChangeController.hasListener)
      _peerStateChangeController.add(new PeerStateChangedEvent(pw, state));
  }

  /**
   * Implements PeerConnectionEventListener onIceGatheringStateChanged
   */
  void onIceGatheringStateChanged(PeerConnection pw, String state) {
    if (_iceGatheringStateChangeController.hasListener)
      _iceGatheringStateChangeController.add(new IceGatheringStateChangedEvent(pw, state));
  }

  /**
   * Implements BinaryDataSentEventListener onWriteChunk
   */
  void onWriteChunk(PeerConnection pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkWriteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataSentEventListener onWroteChunk
   */
  void onWroteChunk(PeerConnection pw, int signature, int sequence, int totalSequences, int bytes) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkWroteEvent(pw, signature, sequence, totalSequences, bytes));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerString
   */
  void onPeerString(PeerConnection pw, String s) {

  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerFile
   */
  void onPeerFile(PeerConnection pw, Blob b) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryFileCompleteEvent(pw, b));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerBuffer
   */
  void onPeerBuffer(PeerConnection pw, ByteBuffer b, int binaryType) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryBufferCompleteEvent(pw, b));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerReadChunk
   */
  void onPeerReadUdpChunk(PeerConnection pw, ByteBuffer buffer, int signature, int sequence, int totalSequences, int bytes, int bytesTotal) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkEvent(pw, buffer, signature, sequence, totalSequences, bytes, bytesTotal, BINARY_PROTOCOL_UDP));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerReadChunk
   */
  void onPeerReadTcpChunk(PeerConnection pw, ByteBuffer buffer, int signature, int bytes, int bytesTotal) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinaryChunkEvent(pw, buffer, signature, null, null, bytes, bytesTotal, BINARY_PROTOCOL_TCP));
  }

  /**
   * Implements BinaryDataReceivedEventListener onPeerSendSuccess
   */
  void onPeerSendSuccess(int signature, int sequence) {
    if (_binaryController.hasListener)
      _binaryController.add(new BinarySendCompleteEvent(signature, sequence));
  }
}