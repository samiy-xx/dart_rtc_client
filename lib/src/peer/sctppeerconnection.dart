part of rtc_client;

class SctpPeerConnection extends PeerConnection {
  static final _logger = new Logger("dart_rtc_client.SctpPeerConnection");
  RtcDataChannel _stringChannel;
  RtcDataChannel _byteChannel;
  RtcDataChannel _blobChannel;

  BlobReader _blobReader;
  BlobWriter _blobWriter;

  ByteReader _byteReader;
  ByteWriter _byteWriter;

  StringReader _stringReader;
  StringWriter _stringWriter;

  SctpPeerConnection(PeerManager pm, RtcPeerConnection p) : super(pm, p) {
    _blobReader = new BlobReader(this);
    _blobWriter = new BlobWriter(this);

    _byteReader = new ByteReader(this);
    _byteWriter = new ByteWriter(this);

    _stringReader = new StringReader(this);
    _stringWriter = new StringWriter(this);
  }

  void setAsHost(bool value) {
    super.setAsHost(value);
    initChannel();
  }

  void initialize() {
    if (_isHost)
      _sendOffer();
  }

  void addStream(MediaStream ms) {
    if (ms == null)
      throw new Exception("MediaStream was null");
    _peer.addStream(ms);
    initialize();
  }

  void addRemoteIceCandidate(RtcIceCandidate candidate) {
    if (candidate == null)
      throw new Exception("RtcIceCandidate was null");

    if (_peer.signalingState != PEER_CLOSED) {
      _logger.fine("(peerwrapper.dart) Receiving remote ICE Candidate ${candidate.candidate}");
      _peer.addIceCandidate(candidate);
    }
  }

  void initChannel() {
    _stringChannel = createStringChannel(PeerConnection.STRING_CHANNEL, {});
    _stringWriter.setChannel(_stringChannel);
    _stringReader.setChannel(_stringChannel);

    _byteChannel = createByteBufferChannel(PeerConnection.BYTE_CHANNEL, {});
    _byteWriter.dataChannel = _byteChannel;
    _byteReader.dataChannel = _byteChannel;

    _blobChannel = createBlobChannel(PeerConnection.BLOB_CHANNEL, {});
    _blobWriter.setChannel(_blobChannel);
    _blobReader.setChannel(_blobChannel);
  }

  void sendString(String s) {

  }

  Future<int> sendBlob(Blob b) {
    return _blobWriter.sendFile(b);
  }

  Future<int> sendFile(File f) {
    return sendBlob(f);
  }

  Future<int> sendBuffer(ByteBuffer buffer, int packetType, bool reliable) {
    return _byteWriter.send(buffer, packetType, reliable);
  }

  void close() {
    _stringChannel.close();
    _byteChannel.close();
    _blobChannel.close();
    super.close();
  }

  void subscribeToReaders(BinaryDataEventListener l) {
    _blobReader.subscribe(l);
    _byteReader.subscribe(l);
    _stringReader.subscribe(l);
  }

  void subscribeToWriters(BinaryDataEventListener l) {
    _blobWriter.subscribe(l);
    _byteWriter.subscribe(l);
    _stringWriter.subscribe(l);
  }

  void _onIceCandidate(RtcIceCandidateEvent c) {
    /*if (c.candidate != null) {
      _manager.getSignaler().sendIceCandidate(this, c.candidate);
    } else {
      _logger.severe("ICE Candidate null");
    }*/
  }

  void _onNegotiationNeeded(Event e) {
    _logger.info("onNegotiationNeeded");

    if (_isHost)
      _sendOffer();
  }

  void _sendOffer() {
    _peer.createOffer()
      .then(_setLocalAndSend)
      .catchError((e) {
        _logger.severe("(peerwrapper.dart) Error creating offer $e");
      });
  }

  void _sendAnswer() {
    _peer.createAnswer()
      .then(_setLocalAndSend)
      .catchError((e) {
        _logger.severe("(peerwrapper.dart) Error creating answer $e");
      });
  }

  void _setLocalAndSend(RtcSessionDescription sd) {
    _peer.setLocalDescription(sd).then((_) {
      _logger.fine("Setting local description was success");
      _manager.getSignaler().sendSessionDescription(this, sd);
    }).catchError((e) {
        _logger.severe("Setting local description failed ${e}");
    });
  }

  void _onNewDataChannelOpen(RtcDataChannelEvent e) {
    super._onNewDataChannelOpen(e);
    var channel = e.channel;

    if (channel.label == PeerConnection.BYTE_CHANNEL) {
      _byteChannel = channel;
      _byteChannel.binaryType = "arraybuffer";
      _byteWriter.dataChannel = _byteChannel;
      _byteReader.dataChannel = _byteChannel;
    } else if (channel.label == PeerConnection.BLOB_CHANNEL) {
      _blobChannel = channel;
      _blobWriter.setChannel(_blobChannel);
      _blobReader.setChannel(_blobChannel);
    } else {
      _stringChannel = channel;
      _stringWriter.setChannel(_stringChannel);
      _stringReader.setChannel(_stringChannel);
    }
  }
}