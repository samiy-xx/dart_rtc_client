part of rtc_client;

const int RTT_STARTING_LATENCY = 30;
const double RTT_MULTIPLIER = 0.1;

class RoundTripCalculator {

  int _currentLatency = RTT_STARTING_LATENCY;
  int get currentLatency => _currentLatency;

  RoundTripCalculator();

  void addToLatency(int t) {
    _currentLatency += t;
  }

  void calculateLatency(int lastSent) {
    int now = new DateTime.now().millisecondsSinceEpoch;
    int diff = (now - lastSent) - _currentLatency;
    int increment = (diff * RTT_MULTIPLIER).toInt();
    _currentLatency += increment;
  }
}

