part of rtc_client;

class DataChannelSetupException implements Exception{
  final String msg;
  final Exception original;
  const DataChannelSetupException([this.msg, this.original]);
  String toString() => msg == null ? "DataChannelSetupException" : msg;
}