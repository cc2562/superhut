import 'dart:collection';

import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_cloud_config_manager.dart';

const int MAX_EXP_LOG_COUNT = 20;
const int MAX_PERF_LOG_COUNT = 100;

class ApmLogQueueManager extends ApmScheduleCenter {
  ApmLogQueueManager() {
    _instance = this;
  }

  static ApmLogQueueManager? _instance;

  static ApmLogQueueManager get singleInstance =>
      _instance ??= ApmLogQueueManager();

  final Queue _preExceptionQueue = Queue<dynamic>();
  final Queue _prePerfQueue = Queue<dynamic>();

  final Queue _exceptionQueue = Queue<dynamic>();
  final Queue _perfQueue = Queue<dynamic>();

  Queue? getQueueObject({
    required ReportLogType reportType,
    required ReportQueueType reportQueueType,
  }) {
    if (reportQueueType == ReportQueueType.send) {
      if (reportType == ReportLogType.exception) {
        return ApmLogQueueManager.singleInstance._exceptionQueue;
      } else {
        return ApmLogQueueManager.singleInstance._perfQueue;
      }
    }
    if (reportQueueType == ReportQueueType.pre) {
      if (reportType == ReportLogType.exception) {
        return ApmLogQueueManager.singleInstance._preExceptionQueue;
      } else {
        return ApmLogQueueManager.singleInstance._prePerfQueue;
      }
    }
    return null;
  }

  void pushLogToQueue(
      {required ReportLogType reportType,
      required dynamic log,
      ReportQueueType reportQueueType = ReportQueueType.pre,
      Function? callback}) {
    nativeTryCatch(handler: () {
      //云控开关
      final ApmCloudConfigManager apmCloudConfigManager =
          ApmCloudConfigManager.singleInstance;
      if(apmCloudConfigManager.isInit){
        bool enableLog = apmCloudConfigManager.flutterPvSamplingHit;
        if (!enableLog) {
          return;
        }
        int enableExcConfig = apmCloudConfigManager.flutterDartExceptionState;
        int excCountConfig = apmCloudConfigManager.flutterDartExceptionMaxCount;
        if (reportType == ReportLogType.exception&&( enableExcConfig != 100 || excCountConfig == 0)) {
          return;
        }

        bool enableAPIConfig = apmCloudConfigManager.flutterIsHaveAPIRateVersion;
        bool enablePVRate = apmCloudConfigManager.flutterPvDetailSamplingHit;
        bool enableAPIRate = apmCloudConfigManager.flutterAPISamplingHit;
        if (enableAPIConfig) {
          if(reportType == ReportLogType.page_fps&&!enablePVRate){
            return;
          }
          if(reportType == ReportLogType.page_perf&&!enablePVRate){
            return;
          }
          if(reportType == ReportLogType.api&&!enableAPIRate){
            return;
          }
        }
      }else{
        if (reportType == ReportLogType.exception) {
          return;
        }
      }

      final Queue? queueObject = getQueueObject(
          reportType: reportType, reportQueueType: reportQueueType);
      if (!(queueObject is Queue)) return;
      if (reportQueueType == ReportQueueType.pre) {
        switch (reportType) {
          case ReportLogType.exception:
            if (queueObject.length < MAX_EXP_LOG_COUNT) {
              queueObject.add(log);
              if (callback != null) callback();
            } else {
              printLog("预处理异常日志队列堆积停止添加记录");
            }
            break;
          default:
            if (queueObject.length <= MAX_PERF_LOG_COUNT) {
              queueObject.add(log);
              if (callback != null) callback();
            } else {
              printLog("预处理性能日志队列堆积停止添加记录");
            }
        }
      } else {
        queueObject.add(log);
      }
    });
  }

  Queue? get(
      {required ReportLogType reportType,
      ReportQueueType reportQueueType = ReportQueueType.pre}) {
    final Queue? obj = getQueueObject(
        reportType: reportType, reportQueueType: reportQueueType);
    return obj;
  }

  bool removeFirst({
    required ReportLogType reportType,
    ReportQueueType reportQueueType = ReportQueueType.pre,
  }) {
    final Queue? obj = getQueueObject(
        reportType: reportType, reportQueueType: reportQueueType);
    if (obj is Queue) {
      obj.removeFirst();
      return true;
    }
    return false;
  }
}
