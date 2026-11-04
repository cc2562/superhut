import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';

Map store = {};

class ApmMethodChannel extends ApmScheduleCenter {
  static const MethodChannel _channel = const MethodChannel('umeng_apm_sdk');

  static Future<Map<String, dynamic>?> getCloudConfig() async {
    try {
      final dynamic cloudConfig = await _channel.invokeMethod('getCloudConfig');
      final convertedMap = Map<String, dynamic>.from(cloudConfig);
      ApmMethodChannel().printLog("GetCloudConfig $convertedMap");
      return convertedMap;
    } catch (e) {
      return null;
    }
  }

  static FutureOr<Map<String, dynamic>?> getNativeParams() async {
    try {
      final dynamic nativeParams =
          await _channel.invokeMethod('getNativeParams');
      final nativeParamsMap = Map<String, dynamic>.from(nativeParams);
      return nativeParamsMap;
    } catch (e) {
      return null;
    }
  }

  static FutureOr<double?> getNativeFPS() async {
    try {
      if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
        final num maxNativeFPS = await _channel.invokeMethod('getNativeFPS');
        if (maxNativeFPS >= 60) {
          return maxNativeFPS.toInt().toDouble();
        }
      }
    } catch (e) {}
    return 60.0;
  }

  static FutureOr<String?> getNativeSdkVersion() async {
    try {
      final String? nativeSdkVersion =
          await _channel.invokeMethod('getSdkVersion');

      return nativeSdkVersion;
    } catch (e) {
      return null;
    }
  }

  static FutureOr<bool> setNativeStore(
      {required String key, required int value}) async {
    try {
      bool status = await _channel
              .invokeMethod('putIntValue', {"key": key, "value": value}) ??
          false;
      return status;
    } catch (e) {
      return false;
    }
  }

  static FutureOr<dynamic> getNativeStore({required String key}) async {
    int value = 0;
    try {
      final result = await _channel.invokeMethod('getIntValue', key);
      if (result is int) {
        return result;
      }
    } catch (e) {}
    return value;
  }
}