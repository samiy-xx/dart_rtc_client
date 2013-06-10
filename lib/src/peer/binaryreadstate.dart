part of rtc_client;

class BinaryReadState {
  final int _state;
  static final BinaryReadState INIT_READ = const BinaryReadState(0);
  static final BinaryReadState READ_SEQUENCE = const BinaryReadState(1);
  static final BinaryReadState READ_TOTAL_SEQUENCES = const BinaryReadState(2);
  static final BinaryReadState READ_LENGTH = const BinaryReadState(3);
  static final BinaryReadState READ_TOTAL_LENGTH = const BinaryReadState(4);
  static final BinaryReadState READ_TYPE = const BinaryReadState(5);
  static final BinaryReadState READ_SIGNATURE = const BinaryReadState(6);
  static final BinaryReadState READ_CONTENT = const BinaryReadState(7);
  static final BinaryReadState FINISH_READ = const BinaryReadState(8);
  static final BinaryReadState READ_CUSTOM = const BinaryReadState(9);
  const BinaryReadState(int s) : _state = s;

  operator ==(Object o) {
    if (!(o is BinaryReadState))
      return false;

    BinaryReadState brs = o as BinaryReadState;
    return brs._state == _state;
  }

  String toString() => _state.toString();
}

