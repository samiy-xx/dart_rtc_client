part of rtc_client_tests;

class StunTests {
  StunEntries _entries;

  run() {
    group('Stun/Turn tests', () {

      setUp(() {
        _entries = new StunEntries();
      });

      tearDown(() {
        _entries.clear();
      });

      test("StunEntry with now all properties set throws when calling toMap", () {
        var stun = new StunEntry();
        expect(stun.toMap(), throws);
      });
    });
  }

  StunEntry createStun(String address, String port) {
    return new StunEntry.filled(address, port);
  }

  TurnEntry createTurn(String address, String port, String userName, String password) {
    return new TurnEntry.filled(address, port, userName, password);
  }
}