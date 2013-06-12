part of rtc_client;

/**
 * This class might be be subject to change.
 * Atm, the RtpDataChannels are set only on Chrome if wanting to use data channel
 */
class PeerConstraints implements Constraints {
  bool _dataChannelEnabled;
  bool _dtlsSrtpKeyAgreement;

  set dataChannelEnabled(bool value) => setDataChannelEnabled(value);
  set dtlsSrtpKeyAgreement(bool value) => _dtlsSrtpKeyAgreement = value;

  bool get dataChannelEnabled => _dataChannelEnabled;
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
      'optional' : [{'RtpDataChannels': _dataChannelEnabled}, {'DtlsSrtpKeyAgreement': 'true'}]
    };
  }
}
