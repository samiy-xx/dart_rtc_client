part of rtc_client;

/**
 * This class might be be subject to change.
 * Atm, the RtpDataChannels are set only on Chrome if wanting to use data channel
 */
class PeerConstraints implements Constraints {
  bool _dataChannelEnabled;

  /** Sets the bitrate of the stream */
  set dataChannelEnabled(bool value) => setDataChannelEnabled(value);

  /** Returns the bitrate */
  bool get dataChannelEnabled => _dataChannelEnabled;

  PeerConstraints() {
    _dataChannelEnabled = false;
  }

  void setDataChannelEnabled(bool value) {
    _dataChannelEnabled = value;
  }

  /*
   * Implements Constraints toMap
   */
  Map toMap() {
    return {
      'optional' : [{'RtpDataChannels': _dataChannelEnabled}]
    };
  }
}
