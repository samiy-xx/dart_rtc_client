part of rtc_client;

/**
 * Attempt in creating an api which allows more control to the application
 * using this.
 */
class DcPc {
  static final _logger = new Logger("dart_rtc_client.DcPc");
  Signaler _signalHandler;
  PeerManager _peerManager;
  DataSource _ds;

  Signaler get signaler => _signalHandler;

  DcPc([Signaler s = null, DataSource ds = null]) {
    _peerManager = new PeerManager();
    _signalHandler = null;

    if (s != null) {
      _signalHandler = s;
    } else {
      if (ds != null)
        _signalHandler = new SimpleSignalHandler(ds);
    }
    _setupListeners();
    _logger.fine("Initialized");
  }

  PeerConnection createPeerConnection(String id) {
    var pc = _peerManager.createPeer();
    pc.id = id;
    return pc;
  }

  void initialize() {
    _signalHandler.initialize();
  }

  void _setupListeners() {
    if (_signalHandler == null)
      throw new Exception("SignalHandler is null");

    _signalHandler.onServerEvent.listen(_onServerEvent);
    _signalHandler.onSignalingStateChanged.listen(_onSignalingEvent);
  }

  void _onServerEvent(ServerEvent e) {

  }

  void _onSignalingEvent(SignalingStateEvent e) {

  }


}