part of rtc_client_tests;

class TestUtils {

  static String genRandomString(int length) {
    StringBuffer out = new StringBuffer();

    while (out.length < length) {
      out.writeCharCode(new Random().nextInt(100));
    }

    return out.toString();
  }
}