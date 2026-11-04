import 'dart:async';
import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:umeng_apm_sdk/src/processor/common_data_processor.dart';

class ExceptionDataProcessor extends CommonDataProcessor {
  // 验证规则
  bool valiDateRule({required String msg, required List? rules}) {
    if (rules is List) {
      for (var i = 0; i < rules.length; i++) {
        dynamic rule = rules[i];
        switch (rule.runtimeType.toString()) {
          case '_RegExp':
            RegExp exp = rule;
            bool matchResult = exp.hasMatch(msg);
            if (matchResult) {
              return true;
            }
            break;
          case 'String':
            bool matchResult = msg.contains(msg);
            if (matchResult) {
              return true;
            }
            break;
          default:
        }
      }
    }
    return false;
  }

  // 调用忽略匹配规则进行过滤
  void _callIgnoreAndMatchRuleFilter(
      ExceptionData exceptionData, Function callback) {
    final Map<String, dynamic>? errorFiltter = getStore[KEY_ERRORFILTER];
    if (errorFiltter != null) {
      Map<String, dynamic> logMap = exceptionData.getPreproccessTypeLog();
      final String msg = logMap[KEY_MSG];
      final List? rules = errorFiltter[KEY_RULES];
      switch (errorFiltter[KEY_MODE]) {
        case 'ignore':
          bool valiDateResult = valiDateRule(msg: msg, rules: rules);
          // 非命中规则摘要可上报
          if (!valiDateResult) {
            callback();
          }
          break;
        case 'match':
          bool valiDateResult = valiDateRule(msg: msg, rules: rules);
          // 命中规则摘要可上报
          if (valiDateResult) {
            callback();
          }
          break;
        default:
      }
    } else {
      callback();
    }
  }

  Future push(
      {required ExceptionData exceptionData, bool? autoCollection}) async {
    _callIgnoreAndMatchRuleFilter(exceptionData, () {
      nativeTryCatch(handler: () async {
        Map<String, dynamic>? nativeInfo =
            await ApmMethodChannel.getNativeParams();
        nativeInfo ??= {};
        final CommonData commonLog = super.createCommonData('error', nativeInfo,
            params: {
              'auto': (autoCollection != null && autoCollection) ? 'Y' : 'N'
            });

        this.pushLogToQueue(
            reportType: ReportLogType.exception,
            reportQueueType: ReportQueueType.pre,
            log: PreProcessData(
              commonLog: commonLog,
              log: exceptionData,
              type: ReportLogType.exception,
            ));
      });
    });
  }
}
