part of rtc_client;

const int RTT_STARTING_LATENCY = 30;
const double RTT_MULTIPLIER = 0.1;
const int RTT_MAX_LATENCY = 500;

class RoundTripCalculator {

  int _currentLatency = RTT_STARTING_LATENCY;
  int get currentLatency => _currentLatency;

  RoundTripCalculator();

  void forceBelowMaxLimit() {
    if (_currentLatency > RTT_MAX_LATENCY)
      _currentLatency = RTT_MAX_LATENCY;
  }

  void addToLatency(int t) {
    _currentLatency += t;
    forceBelowMaxLimit();
  }

  void calculateLatency(int lastSent) {
    new Logger().Debug("Adjusting latency");
    int now = new DateTime.now().millisecondsSinceEpoch;
    int diff = (now - lastSent) - _currentLatency;
    
    //if (diff < (_currentLatency ~/ 2)) {
    //  _currentLatency += diff;
    //} else {
      
      int increment = (diff * RTT_MULTIPLIER).toInt();
      _currentLatency += increment;
    //}
    forceBelowMaxLimit();
    new Logger().Debug("latency is now $_currentLatency");
  }
}

