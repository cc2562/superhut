import 'dart:convert' as convert;
import 'package:flutter/foundation.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_typedef.dart';
import 'package:umeng_apm_sdk/src/data/exception_data.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_flutter_error.dart';
import 'package:umeng_apm_sdk/src/processor/exception_data_processor.dart';

class ExceptionTrace extends ApmScheduleCenter {
  // PlatformDispatcherErrorHandler? handler;
  static FlutterExceptionHandler? handler;

  // 自定义属性字符串最大长度限制
  static int _extraStrLenLimit = 256;

  ExceptionTrace();

  static void init({OnError? onError}) {
    final FlutterExceptionHandler? rawOnError = FlutterError.onError;
    // 捕获Flutter 框架运行时的错误，包括构建期间、布局期间和绘制期间
    ExceptionTrace.handler = (FlutterErrorDetails details) {
      if (details.exception is ApmFlutterError) {
        ExceptionTrace.handleApmSdkException(
            details.exception, details.stack.toString());
      } else {
        nativeTryCatch(handler: () {
          final library = details.library;
          final bool isWidgetsLibrary =
              library is String && 'widgets library'.compareTo(library) == 0;
          ExceptionDataProcessor().push(
              exceptionData: ExceptionData(
                msg: details.exception.toString(),
                stack: _stackSplit(stackStr: details.stack.toString()),
                type: details.exception.runtimeType.toString(),
                level: isWidgetsLibrary
                    ? 'ErrorWidget'
                    : _getErrorType(details.exception),
              ),
              autoCollection: true);
          if (onError != null) {
            onError(details.exception, details.stack);
          }
        });
      }

      return rawOnError!(details);
    };

    FlutterError.onError = handler;
  }

  static handleApmSdkException(dynamic exception, [dynamic stack]) {
    final ExceptionTrace exceptionTrace = ExceptionTrace();
    exceptionTrace.errorLog('==========APM SDK 异常============');
    exceptionTrace.errorLog(exception);
    if (stack != null) {
      exceptionTrace.errorLog(stack!.toString());
    }
    exceptionTrace.errorLog('==================================');
  }

  static String _getErrorType(dynamic exception) {
    return exception is Exception ? 'Exception' : 'Error';
  }

  // 默认切割保留20行堆栈
  static String? _stackSplit({required String stackStr, int line = 20}) {
    List stackList = stackStr.split('\n');
    if (stackList.isEmpty) return '-';
    int len = stackList.length <= line ? stackList.length : line;
    return stackList.sublist(0, len).join('\n');
  }

  // 向异常队列新增记录
  static void _addExceptionRecord(
      {required dynamic msg,
      dynamic stack,
      Map<String, dynamic>? extra,
      bool autoCollection = true}) {
    String? stackStr;

    try {
      stackStr = (stack != null && stack != '')
          ? ExceptionTrace._stackSplit(stackStr: stack.toString())
          : '-';
    } catch (e) {
      stackStr = '-';
    }

    String extraStr = extra is Map ? convert.jsonEncode(extra) : '-';

    extraStr = extraStr.substring(
        0,
        extraStr.length < _extraStrLenLimit
            ? extraStr.length
            : _extraStrLenLimit);

    ExceptionDataProcessor().push(
        exceptionData: ExceptionData(
            msg: msg.toString(),
            stack: stackStr,
            type: msg.runtimeType.toString(),
            level: ExceptionTrace._getErrorType(msg),
            extra: extraStr),
        autoCollection: autoCollection);
  }

  // 分区保护错误异常回调
  static void zonedGuardedErrorHandler({
    required Object exception,
    required dynamic stack,
  }) {
    nativeTryCatch(handler: () {
      _addExceptionRecord(msg: exception, stack: stack);
    });
  }

  // 捕获自定义异常
  static void captureException(
      {required dynamic exception,
      String? stack,
      Map<String, dynamic>? extra}) {
    if (exception == null) return;
    nativeTryCatch(handler: () {
      if (exception is Exception) {
        _addExceptionRecord(
            msg: exception, stack: stack, extra: extra, autoCollection: false);
      }
    });
  }
}
