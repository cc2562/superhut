import 'package:umeng_apm_sdk/src/utils/utils.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';

class ApmCloudConfigManager extends ApmScheduleCenter {
  ApmCloudConfigManager() {
    _instance = this;
  }

  static ApmCloudConfigManager? _instance;

  static ApmCloudConfigManager get singleInstance =>
      _instance ??= ApmCloudConfigManager();

  bool flutterPvSamplingHit = false;

  bool flutterPvDetailSamplingHit = false;

  bool flutterAPISamplingHit = false;

  bool flutterIsHaveAPIRateVersion = false;

  int flutterDartExceptionState = 0;

  int flutterPvMaxCount = 0;

  int flutterDartExceptionMaxCount = 0;

  bool isInit = false;

  setCloudConfig(Map<String, dynamic>? config) {
    config ??= {};
    if (config.containsKey(KEY_PV_SAMPLING_HIT) &&
        config[KEY_PV_SAMPLING_HIT] is bool) {
      flutterPvSamplingHit = config[KEY_PV_SAMPLING_HIT];
      printLog('当前设备采样率命中状态 > $flutterPvSamplingHit');
    }

    if (config.containsKey(KEY_PV_DETAIL_SAMPLING_HIT) &&
        config[KEY_PV_DETAIL_SAMPLING_HIT] is bool) {
      flutterIsHaveAPIRateVersion = true;
      flutterPvDetailSamplingHit = config[KEY_PV_DETAIL_SAMPLING_HIT];
      printLog('当前设备pv采样率命中状态 > $flutterPvDetailSamplingHit');
    }

    if (config.containsKey(KEY_API_SAMPLING_HIT) &&
        config[KEY_API_SAMPLING_HIT] is bool) {
      flutterIsHaveAPIRateVersion = true;
      flutterAPISamplingHit = config[KEY_API_SAMPLING_HIT];
      printLog('当前设备网络采样率命中状态 > $flutterAPISamplingHit');
    }

    if (config.containsKey(KEY_DART_EXCEPTION_STATE) &&
        config[KEY_DART_EXCEPTION_STATE] is int) {
      flutterDartExceptionState = config[KEY_DART_EXCEPTION_STATE];
      if (flutterDartExceptionState != 100) {
        printLog('当前设备异常采集关闭');
      }
    }

    if (config.containsKey(KEY_PV_MAX_COUNT) &&
        config[KEY_PV_MAX_COUNT] is int) {
      flutterPvMaxCount = config[KEY_PV_MAX_COUNT];
    }

    if (config.containsKey(KEY_DART_EXCEPTION_MAX_COUNT) &&
        config[KEY_DART_EXCEPTION_MAX_COUNT] is int) {
      flutterDartExceptionMaxCount = config[KEY_DART_EXCEPTION_MAX_COUNT];
    }
    isInit = true;
  }

  Future<int> getRemainingLogCount(ReportLogType type) async {
    if (ReportLogType.exception == type) {
      final int currentCount =
          await _getNativeStore(keyName: KEY_DART_EXCEPTION_CURRENT_COUNT);
      return flutterDartExceptionMaxCount - currentCount;
    } else {
      final int currentCount =
          await _getNativeStore(keyName: KEY_PV_CURRENT_COUNT);
      return flutterPvMaxCount - currentCount;
    }
  }

  Future<void> setLastLogTimestamp(int timestamp) async {
    await _setNativeStore(keyName: KEY_LAST_LOG_REPORT_TIME, value: timestamp);
  }

  Future<bool> recordLogCount(ReportLogType type, int num) async {
    bool status = true;
    if (ReportLogType.exception == type) {
      final int currentCount =
          await _getNativeStore(keyName: KEY_DART_EXCEPTION_CURRENT_COUNT);
      status = await _setNativeStore(
          keyName: KEY_DART_EXCEPTION_CURRENT_COUNT, value: currentCount + num);
    } else {
      final int currentCount =
          await _getNativeStore(keyName: KEY_PV_CURRENT_COUNT);
      status = await _setNativeStore(
          keyName: KEY_PV_CURRENT_COUNT, value: currentCount + num);
    }
    return status;
  }

  Future<int> _getNativeStore({required String keyName}) async {
    int count = await ApmMethodChannel.getNativeStore(key: keyName);
    return count;
  }

  Future<bool> _setNativeStore(
      {required String keyName, required int value}) async {
    bool setupStatus =
        await ApmMethodChannel.setNativeStore(key: keyName, value: value);
    return setupStatus;
  }

  Future initNativeStore() async {
    int timestamp = await _getNativeStore(keyName: KEY_LAST_LOG_REPORT_TIME);

    if (timestamp >= 0) {
      if (timestamp == 0 || !(isNowDay(timestamp: timestamp))) {
        _setNativeStore(keyName: KEY_DART_EXCEPTION_CURRENT_COUNT, value: 0);
        _setNativeStore(keyName: KEY_PV_CURRENT_COUNT, value: 0);
      }
    }
  }
}
