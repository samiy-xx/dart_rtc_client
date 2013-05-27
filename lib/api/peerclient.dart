part of rtc_client;

class PeerClient implements RtcClient, PeerConnectionEventListener, PeerMediaEventListener,
  PeerDataEventListener, BinaryDataReceivedEventListener, BinaryDataSentEventListener {

  static final _logger = new Logger("dart_rtc_client.PeerClient");

  Signaler _signalHandler;
  PeerManager _peerManager;

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

  PeerClient(Signaler signaler) {
    _signalHandler = signaler;

    _peerManager = new PeerManager();
    _peerManager.subscribe(this);

    _signalHandler = new StreamingSignalHandler(ds);

    _getUserMediaConstraints = new VideoConstraints();
    _peerConstraints = new PeerConstraints();
    _streamConstraints = new StreamConstraints();

    _initializedController = new StreamController<InitializationStateEvent>();
    _mediaStreamAvailableStreamController = new StreamController();
    _mediaStreamRemovedStreamController = new StreamController();

    _peerStateChangeController = new StreamController();
    _iceGatheringStateChangeController = new StreamController();
    _dataChannelStateChangeController = new StreamController();

    _binaryController = new StreamController();

    onServerEvent.listen((ServerEvent e) => _serverEventHandler(e));
    onSignalingStateChanged.listen((SignalingStateEvent e) => _signalingEventHandler(e));
  }


}