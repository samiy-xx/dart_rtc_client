part of rtc_client_tests;

class TestUtils {

  static String genRandomString(int length) {
    String out = "";

    while (out.length < length) {
      out += new String.fromCharCode(new Random().nextInt(100));
    }

    return out;
  }
}