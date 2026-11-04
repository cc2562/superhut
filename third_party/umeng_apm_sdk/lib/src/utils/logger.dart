const String PREFIX = '[UMENG-FLUTTER-APM]--';

mixin BaseLogger {
  Map<String, dynamic>? getStore;
}

abstract class Logger with BaseLogger {
  bool _isProductMode() {
    return bool.fromEnvironment('dart.vm.product');
  }

  void releaseLog(dynamic msg) {
    if (_isProductMode()) {
      this.printLog(msg);
    }
  }

  void warnLog(dynamic msg) {
    if (getStore?['enableLog']) {
      print('$PREFIX[Warn]：$msg');
    }
  }

  void errorLog(dynamic msg) {
    if (getStore?['enableLog']) {
      print('$PREFIX[Error]：$msg');
    }
  }

  void printLog(dynamic msg) {
    if (getStore?['enableLog']) {
      print('$PREFIX[Log]：$msg >>>>>>> ${DateTime.now()}');
    }
  }
}
