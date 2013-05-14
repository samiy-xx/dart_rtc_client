part of rtc_client;

/**
 * PeerManager creates and removes peer connections and assigns media streams to them
 */
class PeerManager extends GenericEventTarget<PeerEventListener> {
  static PeerManager _instance;

  static final _logger = new Logger("dart_rtc_client.PeerManager");

  /*
   * Add local stream to peer connections when created
   */
  bool _setLocalStreamAtStart = false;

  /*
   * false = udp, true = tcp
  */
  bool _reliableDataChannels = false;

  /*
   * Local media stream from webcam/microphone
  */
  LocalMediaStream _ms;

  /*
   * Created peerwrapper
   */
  List<PeerWrapper> _peers;


  PeerConstraints _peerConstraints;
  StreamConstraints _streamConstraints;
  ServerConstraints _serverConstraints;

  /** Add local stream to peer connections when created */
  set setLocalStreamAtStart(bool v) => _setLocalStreamAtStart = v;

  /**
   * Sets the local media stream
   */
  set localMediaStream(LocalMediaStream lms) => setLocalStream(lms);

  /**
   * Returns the local media stream
   */
  LocalMediaStream get localMediaStream => getLocalStream();

  /**
   * Set data channels enabled or disabled for all peers created
   */
  set dataChannelsEnabled(bool value) => _peerConstraints.dataChannelEnabled = value;

  /**
   * Set data channels reliable = tcp or unreliable = udp
   */
  set reliableDataChannels(bool value) => _reliableDataChannels = value;
  bool get reliableDataChannels => _reliableDataChannels;

  factory PeerManager() {
    if (_instance == null)
      _instance = new PeerManager._internal();

    return _instance;
  }

  /*
   * Internal constructor
   */
  PeerManager._internal() {
    _peers = new List<PeerWrapper>();
    _streamConstraints = new StreamConstraints();
    _peerConstraints = new PeerConstraints();
    _serverConstraints = new ServerConstraints();
    _serverConstraints.addStun(new StunServer());
  }

  /**
   * Convenience method
   * Sets the max bit rate to stream constraints
   */
  void setMaxBitRate(int b) {
    _streamConstraints.bitRate = b;
  }

  /**
   * Sets the local media stream from users webcam/microphone to all peers
   */
  void setLocalStream(LocalMediaStream ms) {
    _ms = ms;
    _peers.forEach((PeerWrapper p) {
      p.addStream(ms);
    });
  }

  void setPeerConstraints(PeerConstraints pc) {
    _peerConstraints = pc;
  }

  void setStreamConstraints(StreamConstraints sc) {
    _streamConstraints = sc;
  }

  StreamConstraints getStreamConstraints() {
    return _streamConstraints;
  }
  /**
   * Returns the current local media stream
   */
  MediaStream getLocalStream() {
    return _ms;
  }

  PeerWrapper createPeer() {
    PeerWrapper wrapper;
    try {
      wrapper = _createWrapper(
          new RtcPeerConnection(
              _serverConstraints.toMap(),
              _peerConstraints.toMap()
          )
      );
    } catch (e, s) {
      _logger.severe("$e");
      _logger.severe("$s");
      throw e;
    }
    _add(wrapper);
    return wrapper;
  }

  /*
   * Creates a wrapper for peer connection
   * if _dataChannelsEnabled then wrapper will be data wrapper
   */
  PeerWrapper _createWrapper(RtcPeerConnection p) {
    PeerWrapper wrapper;
    if (_peerConstraints.dataChannelEnabled) {
      _logger.fine("Creating Data Peer Wrapper");
      wrapper = new DataPeerWrapper(this, p);

      (wrapper as DataPeerWrapper).isReliable = _reliableDataChannels;
      //(wrapper as DataPeerWrapper).initChannel();
    } else {
      _logger.fine("Creating Peer Wrapper");
      wrapper = new PeerWrapper(this, p);
    }

    if (_setLocalStreamAtStart && _ms != null)
      wrapper.addStream(_ms);

    p.onAddStream.listen(onAddStream);
    p.onRemoveStream.listen(onRemoveStream);

    p.onSignalingStateChange.listen(onStateChanged);
    p.onIceCandidate.listen(onIceCandidate);

    listeners.where((l) => l is PeerConnectionEventListener).forEach((PeerConnectionEventListener l) {
      l.onPeerCreated(wrapper);
    });
    return wrapper;
  }

  PeerWrapper getWrapperForPeer(RtcPeerConnection p) {
    for (int i = 0; i < _peers.length; i++) {
      PeerWrapper wrapper = _peers[i];
      if (wrapper.peer == p)
        return wrapper;
    }
    return null;
  }

  PeerWrapper findWrapper(String id) {
    for (int i = 0; i < _peers.length; i++) {
      PeerWrapper wrapper = _peers[i];
      if (wrapper.id == id)
        return wrapper;
    }
    return null;
  }

  /**
   * Callback for mediastream removed
   * Notifies listeners that stream was removed from peer
   */
  void onRemoveStream(MediaStreamEvent e) {
    PeerWrapper wrapper = getWrapperForPeer(e.target);

    listeners.where((l) => l is PeerMediaEventListener).forEach((PeerMediaEventListener l) {
      l.onRemoteMediaStreamRemoved(wrapper);
    });
  }

  void onIceCandidate(RtcIceCandidateEvent e) {
    if (e.candidate == null) {
      listeners.where((l) => l is PeerConnectionEventListener).forEach((PeerConnectionEventListener l) {
        l.onIceGatheringStateChanged(getWrapperForPeer(e.target), "finished");
      });
    }
  }
  /**
   * Callback for when a media stream is added to peer
   * Notifies listeners that a media stream was added
   */
  void onAddStream(MediaStreamEvent e) {
    PeerWrapper wrapper = getWrapperForPeer(e.target);

    listeners.where((l) => l is PeerMediaEventListener).forEach((PeerMediaEventListener l) {
      l.onRemoteMediaStreamAvailable(e.stream, wrapper, true);
    });
  }

  /**
   * Signal handler should listen for event onPacketToSend so that this actually gets sent
   */
  void _sendPacket(String p) {
    listeners.where((l) => l is PeerPacketEventListener).forEach((PeerPacketEventListener l) {
      l.onPacketToSend(p);
    });
  }

  /**
   * Closes all peer connections
   */
  void closeAll() {
    for (int i = 0; i < _peers.length; i++) {
      PeerWrapper p = _peers[i];
      p.close();
    }
  }

  /**
   * Removes a single peer wrapper
   * Removed from collection after onStateChanged gets fired
   */
  void remove(PeerWrapper p) {
    p.close();
  }

  void _add(PeerWrapper p) {
    if (!_peers.contains(p))
      _peers.add(p);
  }

  /**
   * Peer state changed
   * Notifies listeners about the state change
   * If readystate changed to closed, remove the peer wrapper and containing peer
   */
  void onStateChanged(Event e) {
    PeerWrapper wrapper = getWrapperForPeer(e.target);
    _logger.fine("onStateChanged: ${wrapper.peer.signalingState}");

    listeners.where((l) => l is PeerConnectionEventListener).forEach((PeerConnectionEventListener l) {
      l.onPeerStateChanged(wrapper, wrapper.peer.signalingState);
    });

    if (wrapper.peer.signalingState == PEER_CLOSED) {
      int index = _peers.indexOf(wrapper);
      if (index >= 0)
        _peers.removeAt(index);
    } else if (wrapper.peer.signalingState == PEER_STABLE) {

    }
  }
}
