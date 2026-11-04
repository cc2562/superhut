import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';

class ApmRequest extends ApmScheduleCenter {
  // 添加一个清理数据的方法，处理 NaN 值
  dynamic _cleanData(dynamic data) {
    if (data is Map) {
      final cleanedMap = <String, dynamic>{};
      data.forEach((key, value) {
        cleanedMap[key.toString()] = _cleanData(value);
      });
      return cleanedMap;
    } else if (data is List) {
      return data.map((item) => _cleanData(item)).toList();
    } else if (data is double && data.isNaN) {
      return 0.0; // 将 NaN 替换为 0.0
    }
    return data;
  }
  // 请求重试
  Future retryHttpClient(
      {required dynamic requestInstance,
      required dynamic body,
      int maxRetries = 1,
      required Duration retryInterval,
      Function? successHandler,
      Function? failHandler}) async {
    final dynamic reqBody;
    if (Platform.operatingSystem == 'ohos') {
      reqBody = _cleanData(body);
    } else {
      reqBody = body;
    }
    int retries = 0;
    while (retries <= maxRetries) {
      try {
        bool resultStatus = await requestInstance(
            data: reqBody,
            successHandler: successHandler,
            failHandler: failHandler);
        if (resultStatus) {
          return resultStatus;
        }
      } catch (e) {}
      retries++;
      await Future.delayed(retryInterval);
    }
    errorLog('重新尝试$maxRetries后未能获得响应');
  }

  Map<String, String> _getRequestHeader(Map<String, dynamic>? data) {
    final appid = getStore[KEY_APPID];
    final sver = getStore[KEY_SDK_VERSION];
    final type = data![KEY_TYPE];
    return {
      'wpk-header': Uri.encodeComponent([
        'app=$appid',
        'cp=gzip',
        'de=1',
        'type=$type',
        'sver=$sver'
      ].join('&'))
    };
  }

  String _generateDynamicFileName(Map<String, dynamic>? data) {
    final type = data![KEY_TYPE] ?? '';
    int reportTime = DateTime.now().microsecondsSinceEpoch;
    return '${reportTime}_$type.txt';
  }

  Future<bool> post(
      {required data, Function? successHandler, Function? failHandler}) async {
    printLog('${json.encode(data)}');
    String url = getStore[KEY_DSN] ?? logUrl;
    final header = _getRequestHeader(data);
    final String fileName = _generateDynamicFileName(data);
    final encoding = GZipCodec();
    final compressedData = encoding.encode(utf8.encode(json.encode(data)));
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll(header);
    final file = http.MultipartFile.fromBytes('file', compressedData,
        filename: fileName);
    request.files.add(file);

    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      Map<dynamic, dynamic>? result = jsonParse(respStr);

      if (result != null && result[KEY_CODE] == 0) {
        printLog('${data![KEY_TYPE]}-日志上报成功');
        if (successHandler != null) {
          successHandler();
        }
        return true;
      }
    } catch (e) {}
    printLog('${data![KEY_TYPE]}-日志上报失败');
    if (failHandler != null) {
      failHandler();
    }
    return false;
  }
}
