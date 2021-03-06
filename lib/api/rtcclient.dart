part of rtc_client;

/**
 * Base interface for the clients exposed by the api.
 * This is interface will expose functionality to connect to the channel server
 *
 * This attempts to offer the functionality in "easy" way to handle
 * http://dev.w3.org/2011/webrtc/editor/webrtc.html
 */
abstract class RtcClient {
  /**
   * Initializes the connection
   */
  void initialize();

  /**
   * If you set this true, some sort of microphone is required
   */
  RtcClient setRequireAudio(bool b);

  /**
   * Webcam or software that emulates video source required if this is true
   */
  RtcClient setRequireVideo(bool b);

  /**
   * Enables datachannel
   */
  RtcClient setRequireDataChannel(bool b);

  /**
   * Channel name. Users join a channel on the server
   */
  RtcClient setChannel(String c);

  /**
   * Gets/Sets the signal handler which is responsible for the handshaking of the participants.
   */
  //Signaler get signalHandler;
  //set signalHandler(Signaler s);
  /**
   * Returns the PeerManager that is responsible for creating and removing peer connections.
   * You can subscribe to some of the peer events trough this.
   */
  PeerManager get peerManager;


  /**
   * Sends a message that goes trough the server to all users in channel
   */
  void sendChannelMessage(String message);

  /**
   * Sends a string trough peer connection
   */
  void sendString(String peerId, String message);



  /**
   * Sends a blob trough peer connection
   */
  void sendBlob(String peerId, Blob data);

  /**
   * Sends a file read as ArayBuffer trough peer connection
   */
  Future<int> sendFile(String peerId, File file);

  /**
   * Sends an ArrayBuffer unreliably trough peer connection
   */
  void sendByteBufferUnReliable(String peerId, ByteBuffer data);

  /**
   * Sends an ArrayBuffer reliably trough peer connection
   */
  Future<int> sendByteBufferReliable(String peerId, ByteBuffer data);

  /**
   * Event that fires when a remote peer offers an video or audio stream
   */
  Stream<MediaStreamAvailableEvent> get onMediaStreamAvailableEvent;

  /**
   * Event that fires when a remote peer removes the video or audio stream
   */
  Stream<MediaStreamRemovedEvent> get onMediaStreamRemovedEvent;

  /**
   * Event fires when signalhandler is ready
   */
  Stream<InitializationStateEvent> get onInitializationStateChangeEvent;

  /**
   * Event fires when signaling has connected to the server via data source
   */
  //Stream<SignalingOpenEvent> get onSignalingOpenEvent;

  /**
   * Datasource connection to the server has closed
   */
  //Stream<SignalingCloseEvent> get onSignalingCloseEvent;

  /**
   * Error when talking to server via data source
   */
  //Stream<SignalingErrorEvent> get onSignalingErrorEvent;

  /**
   * Peer state has changed.
   *
   * According to http://dev.w3.org/2011/webrtc/editor/webrtc.html#state-definitions
   * stable There is no offer­answer exchange in progress. This is also the initial state in which case the local and remote descriptions are empty.
   * have-local-offer  A local description, of type "offer", has been supplied.
   * have-remote-offer A remote description, of type "offer", has been supplied.
   * have-local-pranswer A remote description of type "offer" has been supplied and a local description of type "pranswer" has been supplied.
   * have-remote-pranswer  A local description of type "offer" has been supplied and a remote description of type "pranswer" has been supplied.
   * closed
   */
  Stream<PeerStateChangedEvent> get onPeerStateChangeEvent;

  /**
   * Ice gathering state has changed
   *
   * http://dev.w3.org/2011/webrtc/editor/webrtc.html#rtcicegatheringstate-enum
   * new  The object was just created, and no networking has occurred yet.
   * gathering The ICE engine is in the process of gathering candidates for this RTCPeerConnection.
   * complete  The ICE engine has completed gathering. Events such as adding a new interface or a new TURN server will cause the state to go back to gathering.
   */
  Stream<IceGatheringStateChangedEvent> get onIceGatheringStateChangeEvent;

  Stream<DataChannelStateChangedEvent> get onDataChannelStateChangeEvent;
  /**
   * Message has arrived via data source
   */
  //Stream<DataSourceMessageEvent> get onDataSourceMessageEvent;

  /**
   * Connection to the server has closed
   */
  //Stream<DataSourceCloseEvent> get onDataSourceCloseEvent;

  /**
   * Connection to the server has opened
   */
  //Stream<DataSourceOpenEvent> get onDataSourceOpenEvent;

  /**
   * Connection to server had an error
   */
  //Stream<DataSourceErrorEvent> get onDataSourceErrorEvent;

  /**
   * Received packet from server
   *
   * Raw string can be catched from onDataSourceMessageEvent
   */
  //Stream<PacketEvent> get onPacketEvent;
}