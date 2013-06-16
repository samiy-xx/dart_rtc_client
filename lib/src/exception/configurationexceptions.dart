part of rtc_client;

class StunConfigurationException implements Exception{
  final String msg;
  final Exception original;
  const StunConfigurationException([this.msg, this.original]);
  String toString() => msg == null ? "StunConfigurationException" : msg;
}