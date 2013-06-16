part of rtc_client;

class TurnEntry extends StunEntry {
  String _userName;
  String _password;

  String get userName => _userName;
  String get password => _password;

  set userName(String v) => setUserName(v);
  set password(String v) => setPassword(v);

  TurnEntry() : super() {
    _userName = "";
    _password = "";
    _address = "";
    _port = "";
  }

  TurnEntry.filled(String address, String port, String userName, String password) : super.filled(address, port) {
    _userName = userName;
    _password = password;
  }

  void setUserName(String v) {
    _userName = v;
  }

  void setPassword(String v) {
    _password = v;
  }

  Map toMap() {
    if (Str.isNullOrEmpty(_userName) || Str.isNullOrEmpty(_password))
      throw new StunConfigurationException("Username or Password has not been set");
    return {
      'url': 'turn:$_userName@$_address:$_port',
      'credential': _password
    };
  }
}