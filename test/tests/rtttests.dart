part of rtc_client_tests;

class RoundTripTimerTests {
  run() {
    group('RoundTripTimerTests', () {
      RoundTripCalculator timer;
      
      setUp(() {
        timer = new RoundTripCalculator();
      });

      tearDown(() {
        timer = null;
      });
      
      test("RTT, When created, is not null", () {
        expect(timer, isNotNull);
      });
      
      test("RTT, When created, has property for latency", () {
        expect(timer.currentLatency, isNotNull);
        expect(timer.currentLatency, equals(RTT_STARTING_LATENCY));
      });
      
      test("RTT, Adding to latency, increases latency", () {
        int toAdd = 50;
        timer.addToLatency(toAdd);
        expect(timer.currentLatency, equals(RTT_STARTING_LATENCY + toAdd));
      });
      
      test("RTT, Adding over max limit, constraints latency to limit", () {
        int toAdd = 1000;
        timer.addToLatency(toAdd);
        expect(timer.currentLatency, equals(RTT_MAX_LATENCY));
      });
      
      test("RTT, calculating new latency, gives correct increment", () {
        int last = new DateTime.now().millisecondsSinceEpoch - 50;
        timer.calculateLatency(last);
        expect(timer.currentLatency, equals(32));
      });
    });
  }
}



