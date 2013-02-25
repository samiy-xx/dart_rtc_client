part of rtc_client;


class StunServer {
  String _address;
  String _port;

  String get address => _address;
  String get port => _port;
  set address(String v) => setAddress(v);
  set port(String v) => setPort(v);

  StunServer() {
    _address = "stun.l.google.com";
    _port = "19302";
  }

  void setAddress(String v) {
    _address = v;
  }

  void setPort(String v) {
    _port = v;
  }

  Map toMap() {
    return {
      'url': 'stun:$_address:$_port'
    };
  }
}

class TurnServer extends StunServer {
  String _userName;
  String _password;

  String get userName => _userName;
  String get password => _password;

  set userName(String v) => setUserName(v);
  set password(String v) => setPassword(v);

  TurnServer() : super() {
    _userName = "";
    _password = "";
    _address = "";
    _port = "";
  }

  void setUserName(String v) {
    _userName = v;
  }

  void setPassword(String v) {
    _password = v;
  }

  Map toMap() {
    return {
      'url': 'turn:$_userName@$_address:$_port',
      'credential': _password
    };
  }
}

class ServerConstraints implements Constraints {
  List<StunServer> _stunServers;
  List<TurnServer> _turnServers;

  ServerConstraints() {
    _stunServers = new List<StunServer>();
    _turnServers = new List<TurnServer>();
  }

  ServerConstraints addStun(StunServer ss) {
    if (!_stunServers.contains(ss))
      _stunServers.add(ss);
  }

  ServerConstraints addTurn(TurnServer ss) {
    if (!_turnServers.contains(ss))
      _turnServers.add(ss);
  }

  void clear() {
    _stunServers.clear();
    _turnServers.clear();
  }
  /**
   * Implements Constraints toMap
   */
  Map toMap() {
    Map con = new Map();
    con['iceServers'] = new List<Object>();
    _stunServers.forEach((StunServer ss) => con['iceServers'].add(ss.toMap()));
    _turnServers.forEach((TurnServer ts) => con['iceServers'].add(ts.toMap()));
    return con;
  }
}


