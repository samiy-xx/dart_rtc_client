part of rtc_client;
// Shamelessly borrowed from device.dart

class Browser {
  static String get userAgent => window.navigator.userAgent;
  static bool _isOpera;
  static bool _isIE;
  static bool _isFirefox;
  static bool _isWebKit;

  static bool get isOpera {
    if (_isOpera == null) {
      _isOpera = userAgent.contains("Opera", 0);
    }
    return _isOpera;
  }

  static bool get isIE {
    if (_isIE == null) {
      _isIE = !isOpera && userAgent.contains("MSIE", 0);
    }
    return _isIE;
  }

  static bool get isWebKit {
    if (_isWebKit == null) {
      _isWebKit = !isOpera && userAgent.contains("WebKit", 0);
    }
    return _isWebKit;
  }

  static bool get isFirefox {
    if (_isFirefox == null) {
      _isFirefox = userAgent.contains("Firefox", 0);
    }
    return _isFirefox;
  }

}