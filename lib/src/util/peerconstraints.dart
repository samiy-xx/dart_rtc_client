part of rtc_client;

/**
 * This class might be be subject to change.
 * Atm, the RtpDataChannels are set only on Chrome if wanting to use data channel
 */
class PeerConstraints implements Constraints {
  bool _dataChannelEnabled;
  bool _dtlsSrtpKeyAgreement;

  /** Sets the bitrate of the stream */
  set dataChannelEnabled(bool value) => setDataChannelEnabled(value);

  /** God knows? */
  set dtlsSrtpKeyAgreement(bool value) => _dtlsSrtpKeyAgreement = value;

  /** Returns the bitrate */
  bool get dataChannelEnabled => _dataChannelEnabled;

  /** Oh hell */
  bool get dtlsSrtpKeyAgreement => _dtlsSrtpKeyAgreement;

  PeerConstraints() {
    _dataChannelEnabled = false;
    _dtlsSrtpKeyAgreement = false;
  }

  void setDataChannelEnabled(bool value) {
    _dataChannelEnabled = value;
  }

  /**
   * Implements Constraints toMap
   */
  Map toMap() {
    return {
      //'optional' : [{'RtpDataChannels': _dataChannelEnabled}]
      'optional' : [{'RtpDataChannels': _dataChannelEnabled}, {'DtlsSrtpKeyAgreement': _dtlsSrtpKeyAgreement}]
    };
  }
}
