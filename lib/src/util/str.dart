part of rtc_client;

/**
 * String utils
 */
class Str {
  static bool isNullOrEmpty(String string) {
    if (string == null)
      return true;

    return string.isEmpty;
  }
}