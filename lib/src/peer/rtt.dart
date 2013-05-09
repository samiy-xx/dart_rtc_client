part of rtc_client;

const int RTT_STARTING_LATENCY = 10;
const double RTT_MULTIPLIER = 0.01;
const int RTT_MAX_LATENCY = 500;

class RoundTripCalculator {
  int _currentLatency = RTT_STARTING_LATENCY;
  int get currentLatency => _currentLatency;

  RoundTripCalculator();

  void _forceMaxLimit() {
    if (_currentLatency > RTT_MAX_LATENCY)
      _currentLatency = RTT_MAX_LATENCY;
  }

  void addToLatency(int t) {
    _currentLatency += t;
    _forceMaxLimit();
  }

  void calculateLatency(int lastSent) {
    int now = new DateTime.now().millisecondsSinceEpoch;
    int diff = (now - lastSent) - _currentLatency;
    int increment = ((diff ~/4) * RTT_MULTIPLIER).toInt();
    //_currentLatency += increment;
    //print("Latency now $_currentLatency");
    _currentLatency = 5;
    _forceMaxLimit();
  }
}

