part of rtc_client;


class StunServer {
  String _address;
  String _port;

  StunServer() {
    _address = "stun.l.google.com";
    _port = "19302";
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

  TurnServer() : super() {
    _userName = "";
    _password = "";
    _address = "";
    _port = "";
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


