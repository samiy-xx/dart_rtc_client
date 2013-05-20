part of rtc_client;

/**
 * PeerWrapper
 * Wraps the peer connection comfortably
 */
class PeerWrapper extends GenericEventTarget<PeerEventListener>{
  static final _logger = new Logger("dart_rtc_client.PeerWrapper");
  /** Session Description type offer */
  final String SDP_OFFER = 'offer';

  /** Session Description type answer */
  final String SDP_ANSWER = 'answer';

  RtcPeerConnection _peer;
  PeerManager _manager;
  bool _isHost = false;

  String _id;
  String _channelId;
  String get id => _id;
  String get channel => _channelId;
  set id(String value) => _id = value;
  set channel(String value) => _channelId = value;


  RtcPeerConnection get peer => _peer;
  bool get isHost => _isHost;
  set isHost(bool value) => setAsHost(value);

  String get state => _peer.signalingState;
  String get iceConnectionState => _peer.iceConnectionState;
  String get iceGatheringState => _peer.iceGatheringState;

  PeerWrapper(PeerManager pm, RtcPeerConnection p) {
    _peer = p;
    _manager = pm;
    _peer.onIceCandidate.listen(_onIceCandidate);
    _peer.onNegotiationNeeded.listen(_onNegotiationNeeded);
    _peer.onIceConnectionStateChange.listen(_onIceChange);
    _peer.onSignalingStateChange.listen(_onStateChange);

  }

  void setAsHost(bool value) {
    _isHost = value;
  }

  /**
   * Sets the local session description
   * after offer created or replied with answer
   */
  void setSessionDescription(RtcSessionDescription sdp) {
    _peer.setLocalDescription(sdp).then((val) {
        _logger.fine("(peerwrapper.dart) Setting local description was success $val");
    }).catchError((e) {
        _logger.severe("(peerwrapper.dart) setting local description failed ${e}");
    });
  }

  /**
   * Remote description comes over datasource
   * if the type is offer, then a answer must be created
   */
  void setRemoteSessionDescription(RtcSessionDescription sdp) {

      _peer.setRemoteDescription(sdp).then((val) {
        _logger.fine("(peerwrapper.dart) Setting remote description was success $val");
      })
      .catchError((e) {
        _logger.severe("(peerwrapper.dart) setting remote description failed ${e}");
      });

      if (sdp.type == SDP_OFFER)
        _sendAnswer();
  }

  /**
   * Can be used to initialize connection if not wanting to add mediastream right away
   */
  void initialize() {
    if (isHost)
      _sendOffer();
  }

  /*
   * Creates offer and calls callback
   */
  void _sendOffer() {
    _peer.createOffer().then(_onOfferSuccess)
    .catchError((e) {
      _logger.severe("(peerwrapper.dart) Error creating offer $e");
    });
  }

  /*
   * Answer for offer
   */
  void _sendAnswer() {
    _peer.createAnswer().then(_onAnswerSuccess).catchError((e) {

    });
  }

  void _onStateChange(Event e) {

  }

  /*
   * Send the session description created by _sendOffer to the remote party
   * and set is our local session description
   */
  void _onOfferSuccess(RtcSessionDescription sdp) {
    _logger.fine("Offer created, sending");
    sdp = hackTheSdp(sdp);
    setSessionDescription(sdp);

    _manager._sendPacket(PacketFactory.get(new DescriptionPacket.With(sdp.sdp, 'offer', _id, _channelId)));
  }

  /*
   * Send the session description created by _sendAnswer to the remote party
   * and set it our local session description
   */
  void _onAnswerSuccess(RtcSessionDescription sdp) {
    sdp = hackTheSdp(sdp);

    _logger.fine("(peerwrapper.dart) Answer created, sending");
    setSessionDescription(sdp);

    _manager._sendPacket(PacketFactory.get(new DescriptionPacket.With(sdp.sdp, 'answer', _id, _channelId)));
  }

  RtcSessionDescription hackTheSdp(RtcSessionDescription sd) {
    _logger.fine("Hacking created session description for more banswidth");

    String hacked = sd.sdp.replaceFirst("b=AS:30", "b=AS:1638400");

    RtcSessionDescription newSdp = new RtcSessionDescription({
      'sdp':hacked,
      'type':sd.type
    });

    return newSdp;
  }

  /**
   * Ads a MediaStream to the peer connection
   * TODO: Find out why the constraints throw DOMException on chome 25. Works on dartium.
   * As an fallback, call addStream without constraints if DOMException happends.
   */
  void addStream(MediaStream ms) {
    if (ms == null)
      throw new Exception("MediaStream was null");
    _logger.fine("Adding stream to peer $id");
    try {
      _peer.addStream(ms, _manager.getStreamConstraints().toMap());
    } on DomException catch(e, s) {
      _logger.severe("DOM Error setting constraints: $e ${_manager.getStreamConstraints().toMap().toString()}");
      _peer.addStream(ms);
    } on Exception catch (e) {
      _logger.severe("Exception on adding stream $e");
    } catch(e) {
      _logger.severe("Exception on adding stream $e");
    }
  }

  /*
   * Gets fired whenever there's a change in peer connection
   * ie. when you create a peer connection and add an mediastream there.
   *
   * Send an offer if isHost property is true
   * means we're hosting and the other party must reply with answer
   */
  void _onNegotiationNeeded(Event e) {
    _logger.info("onNegotiationNeeded");

    if (isHost)
      _sendOffer();
  }

  /**
   * These you get from datasource
   * at the moment, a null RtcIceCandidate means that connection is done(tm) =P
   */
  void addRemoteIceCandidate(RtcIceCandidate candidate) {
    if (candidate == null)
      throw new Exception("RtcIceCandidate was null");

    if (_peer.signalingState != PEER_CLOSED) {
      _logger.fine("(peerwrapper.dart) Receiving remote ICE Candidate ${candidate.candidate}");
      _peer.addIceCandidate(candidate);
    }
  }

  /*
   * Peer connection generated a ice candidate and this must be delivered to the
   * other party via datasource
   */
  void _onIceCandidate(RtcIceCandidateEvent c) {

    if (c.candidate != null) {
      //_log.Debug("(peerwrapper.dart) (ice gathering state ${_peer.iceGatheringState}) (ice state ${_peer.iceState}) Sending local ICE Candidate ${c.candidate.candidate} ");
      IcePacket ice = new IcePacket.With(c.candidate.candidate, c.candidate.sdpMid, c.candidate.sdpMLineIndex, id);
      _manager._sendPacket(PacketFactory.get(ice));
    } else {
      //_log.Warning("(peerwrapper.dart) Null Ice Candidate, gathering complete");
    }
  }

  /*
   * Doesnt seem to fire with stable stable dartium
   * TODO: find out where the hell is ongatheringstate
   */
  void _onIceChange(Event c) {
    _logger.fine("(peerwrapper.dart) ICE Change ${c} (ice gathering state ${_peer.iceGatheringState}) (ice state ${_peer.iceConnectionState})");
  }

  void _onRTCError(String error) {
    _logger.severe("(peerwrapper.dart) RTC ERROR : $error");
  }

  /**
   * Close the peer connection if not closed already
   */
  void close() {
    _logger.severe("(peerwrapper.dart) Closing peer");
    if (_peer.signalingState != PEER_CLOSED)
      _peer.close();
  }
}
