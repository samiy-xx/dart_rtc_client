part of rtc_client;

class PeerWrapperNullException implements Exception{
  final String msg;
  final Exception original;
  const PeerWrapperNullException([this.msg, this.original]);
  String toString() => msg == null ? "PeerWrapperNullException" : msg;
}

class PeerWrapperTypeException implements Exception{
  final String msg;
  final Exception original;
  const PeerWrapperTypeException([this.msg, this.original]);
  String toString() => msg == null ? "PeerWrapperTypeException" : msg;
}

