import 'dart:io';
import 'dart:isolate';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

class GlobalStore {
  GlobalStore() {
    _instance = this;
  }

  static GlobalStore? _instance;

  static GlobalStore get singleInstance => _instance ??= GlobalStore();

  Map<String, dynamic> _data = {
    'appid': null,
    'enableLog': false,
    'enableTrackingPageFps': false,
    'enableTrackingPagePerf': false,
    'enableTrackingApi': false,
    'dsn': null,
    'processId': pid,
    'threadId': Isolate.current.hashCode,
    'errorFilter': null,
    'name': '',
    'bver': '',
    'env': null,
    'projectType': 0,
    'dartVer': '',
    'sessionId': '',
    'sdkVersion': '',
    'flutterVersion': '',
    'engineVersion': '',
    'url': '',
    'pvId': '',
    'baseInfo': null,
    'currentRoute': null,
    // 0：页面初始化 1：手势滚动 2：其他
    'appStatus': 2,
    'maxFps': 60.0,
    'useBoostPlugin': 0, // 是否使用Flutter Boost插件
  };

  void setProperty({required String name, dynamic value}) {
    if (_data.containsKey(name)) {
      this._data[name] = value;
    }
  }

  void setMultiProperty({required List<Map<String, dynamic>>? config}) {
    if (config != null) {
      config.forEach((keyValMap) {
        setProperty(name: keyValMap[KEY_NAME], value: keyValMap[KEY_VALUE]);
      });
    }
  }

  Map<String, dynamic> get getStore => this._data;
}
