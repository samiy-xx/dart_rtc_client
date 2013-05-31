part of rtc_client;

/**
 * Base PeerEventLister interface
 */
abstract class PeerEventListener {
}

/**
 * Interface for peer connection related notifications
 */
abstract class PeerConnectionEventListener extends PeerEventListener {
  void onPeerCreated(PeerConnection pc);
  /**
   * Notifies listeners that peer state has changed
   */
  void onPeerStateChanged(PeerConnection pc, String state);

  /**
   * Notifies listeners about ice state changes
   */
  void onIceGatheringStateChanged(PeerConnection pc, String state);
}

/**
 * Interface for peer media stream related notifications
 */
abstract class PeerMediaEventListener extends PeerEventListener {
  /**
   * Remote media stream available from peer
   */
  void onRemoteMediaStreamAvailable(MediaStream ms, PeerConnection pc, bool main);

  /**
   * Media stream was removed
   */
  void onRemoteMediaStreamRemoved(PeerConnection pc);
}

/**
 * Interface for peer packet (datasource) related notifications
 */
abstract class PeerPacketEventListener extends PeerEventListener {
  /**
   * Packet needs to be sent
   */
  void onPacketToSend(String p);
}

/**
 * Interface for DataChannel related stuff
 */
abstract class PeerDataEventListener extends PeerEventListener {
  /**
   * Data received from data channel
   */
  void onDataReceived(int buffered);

  /**
   * Channel state changed
   */
  void onChannelStateChanged(PeerConnection pc, String state);

  /**
   * Packet arrived trough data channel
   */
  //void onPacket(DataPeerWrapper pw, Packet p);

}
