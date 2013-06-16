part of rtc_client;

class StunEntries implements Constraints {
  List<StunEntry> _stunServers;
  List<TurnEntry> _turnServers;

  StunEntries() {
    _stunServers = new List<StunEntry>();
    _turnServers = new List<TurnEntry>();
  }

  void addStun(StunEntry entry) {
    if (!_stunServers.contains(entry))
      _stunServers.add(entry);
  }

  void addTurn(TurnEntry entry) {
    if (!_turnServers.contains(entry))
      _turnServers.add(entry);
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
    _stunServers.forEach((StunEntry ss) => con['iceServers'].add(ss.toMap()));
    _turnServers.forEach((TurnEntry ts) => con['iceServers'].add(ts.toMap()));
    return con;
  }
}


