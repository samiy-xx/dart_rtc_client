part of rtc_client;

class StunEntry {
  String _address;
  String _port;

  String get address => _address;
  String get port => _port;

  set address(String v) => setAddress(v);
  set port(String v) => setPort(v);

  StunEntry() {
    _address = "stun.l.google.com";
    _port = "19302";
  }

  StunEntry.filled(String address, String port) {
    _address = address;
    _port = port;
  }

  factory StunEntry.google() {
    return new StunEntry()
    ..address = "stun.l.google.com"
    ..port = "19302";
  }

  void setAddress(String v) {
    _address = v;
  }

  void setPort(String v) {
    _port = v;
  }

  Map toMap() {
    if (Str.isNullOrEmpty(_address) || Str.isNullOrEmpty(_port))
      throw new StunConfigurationException("Address or port has not been set");
    return {
      'url': 'stun:$_address:$_port'
    };
  }
}