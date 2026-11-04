import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:umeng_apm_sdk/src/core/apm_flutter_error.dart';

int getTimestamp() {
  return DateTime.now().millisecondsSinceEpoch;
}

void nativeTryCatch({required Function handler}) {
  try {
    handler()?.then((result) {}, onError: (exception, stackTrace) {
      Future.error(ApmFlutterError(exception, stackTrace));
    });
  } catch (exception, stack) {
    print('==========APM SDK 异常============');
    print(exception);
    print(stack);
    print('==================================');
  }
}

// 判断是否为当天
bool isNowDay({required int timestamp}) {
  DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  DateTime now = DateTime.now();
  return dateTime.day == now.day;
}

// 获取字符串字节数
int getSizeInBytes(String str) {
  // 将字符串转化为 UTF-8 编码
  List<int> utf8Bytes = utf8.encode(str);

  // 计算字符串占用的字节数
  int sizeInBytes = utf8Bytes.length;

  return sizeInBytes;
}

//检查字符串字节数是否超限
bool checkStringSize(String str, int maxSize) {
  int bytes = getSizeInBytes(str);
  // 判断字符串大小是否超过最大限制
  return bytes > maxSize;
}

Map<dynamic, dynamic>? jsonParse(String jsonString) {
  try {
    final jsonMap = json.decode(jsonString);
    return jsonMap;
    // 处理JSON对象
  } catch (e) {
    return null;
    // 处理异常
  }
}

String getRandomStr({required int len}) {
  final _random = Random();
  const _availableChars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  final randomString = List.generate(len,
          (index) => _availableChars[_random.nextInt(_availableChars.length)])
      .join();

  return randomString;
}

// 获取Dart SDK 版本
String? getDartVersion() {
  return Platform.version;
}

// 生成Seesion id
String? createSessionId() {
  final int nowTime = DateTime.now().millisecondsSinceEpoch;
  return getRandomStr(len: 10) + nowTime.toString();
}
