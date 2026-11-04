import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/core/apm_request.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_log_queue_manager.dart';
import 'package:umeng_apm_sdk/src/core/apm_cloud_config_manager.dart';

class ApmReportLog extends ApmScheduleCenter {
  int prefLogMergeNumberLimit = 10;

  int exceptionLogMergeNumberLimit = 5;

  late final int logMaxSizeLimit = 20 * 1024;

  // 异常日志循环时间 5s
  int pollTime = 5;

  ApmReportLog();

  void subscribePV() {
    subscribeEvent({
      "type": ACTIONS.SEND_PV_LOG,
      "handler": (data) {
        logPreProcessHandler(reportLogType: ReportLogType.pv);
      }
    });
  }

  void subscribePage() {
    subscribeEvent({
      "type": ACTIONS.SEND_PAGE_PERF_LOG,
      "handler": (data) {
        logPreProcessHandler(reportLogType: ReportLogType.page_perf);
      }
    });
    subscribeEvent({
      "type": ACTIONS.SEND_PAGE_FPS_LOG,
      "handler": (data) {
        logPreProcessHandler(reportLogType: ReportLogType.page_fps);
      }
    });
  }

  void subscribeAPI() {
    subscribeEvent({
      "type": ACTIONS.SEND_API_LOG,
      "handler": (data) {
        logPreProcessHandler(reportLogType: ReportLogType.api);
      }
    });
  }

  void startTimerPollSendQueue() {
    Timer.periodic(Duration(seconds: pollTime), (Timer t) {
      nativeTryCatch(handler: () {
        logPreProcessHandler(reportLogType: ReportLogType.exception);
      });
    });
  }

  String? _getHeaderLog() {
    return HeaderData(
      name: getStore['name'],
      bver: getStore['bver'],
      flutterVer: getStore['flutterVersion'],
      engineVer: getStore['engineVersion'],
      dartVer: getStore['dartVer'],
      sdkVer: getStore['sdkVersion'],
      fsid: getStore['sessionId'],
      projectType: getStore['projectType'],
      env: getStore['env'],
      useBoostPlugin: getStore['useBoostPlugin'],
    ).getSendTypeLog();
  }

  Map<String, dynamic>? _getBaseInfo() {
    return getStore[KEY_BASEINFO];
  }

  Map<String, dynamic>? _logMerge(
      {required List logs, ReportLogType logType = ReportLogType.pv}) {
    if (logs.isEmpty) return null;
    List sendLogs = [];
    logs.forEach((element) {
      Map? obj = element!.get();
      dynamic commonInstance = obj![KEY_COMMON];
      dynamic logInstance = obj[KEY_LOG];
      String commonStr = commonInstance!.getSendTypeLog();
      String logStr = logInstance!.getSendTypeLog();
      if (commonStr.isEmpty || logStr.isEmpty) return;
      sendLogs.add('$commonStr' + '|\$|' + '$logStr');
    });
    String? headerLog = _getHeaderLog();
    Map<String, dynamic>? baseInfo = _getBaseInfo();
    if (baseInfo == null || baseInfo.isEmpty) return null;
    if (headerLog == null || headerLog.isEmpty) return null;
    baseInfo[KEY_FLUTTER] = '$headerLog|^|${sendLogs.join(',')}';

    baseInfo[KEY_TYPE] = (logType == ReportLogType.exception
        ? KEY_FLUTTER_ERROR
        : KEY_FLUTTER_PERF);
    return baseInfo;
  }

  void _requestSendLog(
      {required List logList, ReportLogType logType = ReportLogType.pv}) {
    Map<String, dynamic>? fullLog = _logMerge(logs: logList, logType: logType);

    if (fullLog is Map) {
      final ApmRequest ins = ApmRequest();
      final ApmCloudConfigManager apmCloudConfigManager =
          ApmCloudConfigManager.singleInstance;
      ins.retryHttpClient(
          body: fullLog,
          requestInstance: ins.post,
          maxRetries: 1,
          retryInterval: Duration(seconds: 3),
          successHandler: () async {
            bool isSuccess = await apmCloudConfigManager.recordLogCount(
                logType, logList.length);
            if (isSuccess) {
              DateTime now = DateTime.now();
              apmCloudConfigManager
                  .setLastLogTimestamp(now.millisecondsSinceEpoch);
            } else {
              warnLog('$logType 记数失败');
            }
            return;
          },
          failHandler: () {});
    }
  }

  int _getLogMergeCount(ReportLogType reportLogType, int diffVal) {
    final int mergeCount = reportLogType == ReportLogType.exception
        ? exceptionLogMergeNumberLimit
        : prefLogMergeNumberLimit;
    return diffVal >= mergeCount ? mergeCount : diffVal;
  }

  void logPreProcessHandler({required ReportLogType reportLogType}) {
    int logSize = 0;
    List logList = [];
    int index = 0;
    nativeTryCatch(handler: () async {
      final ApmLogQueueManager instance = ApmLogQueueManager.singleInstance;
      final Queue? queue = instance.getQueueObject(
          reportType: reportLogType, reportQueueType: ReportQueueType.pre);
      final ApmCloudConfigManager apmCloudConfigManager =
          ApmCloudConfigManager.singleInstance;

      if (queue is Queue && queue.length != 0) {
        await apmCloudConfigManager.initNativeStore();

        int diffVal =
            await apmCloudConfigManager.getRemainingLogCount(reportLogType);

        if (diffVal <= 0) {
          if (reportLogType == ReportLogType.exception) {
            warnLog('异常日志到达最高上报限制');
          } else {
            warnLog('性能日志（pv、page_per、page_fps、api）到达最高上报限制');

            // 性能日志上报数到达上限 关闭页面帧率和页面性能检测减少对页面的性能影响
            setStoreMultiProperty([
              {"name": 'enableTrackingPageFps', "value": false},
              {"name": 'enableTrackingPagePerf', "value": false},
              {"name": 'enableTrackingApi', "value": false},
            ]);
          }
          return;
        } else {
          //  如临时调整日志上报数 可重新开启检测
          setStoreMultiProperty([
            {"name": 'enableTrackingPageFps', "value": true},
            {"name": 'enableTrackingPagePerf', "value": true},
            {"name": 'enableTrackingApi', "value": true},
          ]);
        }
        final int mergeCount = _getLogMergeCount(reportLogType, diffVal);
        Iterable<dynamic> logs = queue.take(mergeCount);
        if (logs.length == 0) return;

        if (reportLogType == ReportLogType.exception) {
          printLog('处理异常日志数${logs.length}');
        } else {
          printLog('处理性能日志（pv、page_perf、page_fps、api）数${logs.length}');
        }

        for (PreProcessData element in logs) {
          logList.add(element);

          Map<String, dynamic>? fullLog =
              _logMerge(logs: logList, logType: ReportLogType.exception);

          if (fullLog is Map && fullLog!.isNotEmpty) {
            try {
              String fullLogStr = jsonEncode(fullLog);
              logSize += getSizeInBytes(fullLogStr);

              bool result = checkStringSize(fullLogStr, logMaxSizeLimit);
              if (index == logs.length - 1) {
                printLog('累计日志字节大小$logSize');
              }

              if (result) {
                if (logList.length == 1) {
                  queue.removeFirst();
                }
                logList.removeLast();
                break;
              }
            } catch (e) {}
          }
          index++;
        }

        if (logList.length > 0) {
          logList.forEach((element) {
            queue.removeWhere((el) {
              return element == el;
            });
          });
        }

        _requestSendLog(
            logList: logList,
            logType: reportLogType != ReportLogType.exception
                ? ReportLogType.perf
                : ReportLogType.exception);
      }
    });
  }
}
