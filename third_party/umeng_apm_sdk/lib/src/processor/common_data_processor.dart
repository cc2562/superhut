import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_log_queue_manager.dart';

class CommonDataProcessor extends ApmScheduleCenter {
  CommonData? commonData;
  CommonDataProcessor({this.commonData});

  CommonData createCommonData(String logType, Map? nativeInfo,
      {Map<String, dynamic>? params}) {
    return CommonData(
        logType: logType,
        url: getStoreUrl() ?? '-',
        pvId: getStorePvId() ?? '-',
        access: getNativeInfoAccess(nativeInfo) ?? '-',
        accessSubtype: getNativeInfoAccessSubtype(nativeInfo) ?? '-',
        battery: getNativeInfoBattery(nativeInfo) ?? '-',
        temperature: getNativeInfoTemperature(nativeInfo) ?? '-',
        diskRatio: getNativeInfoDiskRatio(nativeInfo) ?? '-',
        state: getNativeInfoState(nativeInfo) ?? '-',
        sid: getNativeInfoSessionId(nativeInfo) ?? '-',
        auto: params?['auto'] ?? 'Y');
  }

  void pushLogToQueue(
      {required ReportLogType reportType,
      required ReportQueueType reportQueueType,
      required PreProcessData log,
      Function? callback}) {
    ApmLogQueueManager.singleInstance.pushLogToQueue(
        reportType: reportType,
        reportQueueType: reportQueueType,
        log: log,
        callback: callback);
  }

  String? getStoreUrl() {
    return getStore['url'];
  }

  String? getStorePvId() {
    return getStore['pvId'];
  }

  String? getNativeInfoAccess(Map? nativeInfo) {
    return nativeInfo?['um_access'];
  }

  String? getNativeInfoAccessSubtype(Map? nativeInfo) {
    return nativeInfo?['um_access_subtype'];
  }

  dynamic getNativeInfoBattery(Map? nativeInfo) {
    return nativeInfo?['battery'];
  }

  dynamic getNativeInfoTemperature(Map? nativeInfo) {
    return nativeInfo?['temperature'];
  }

  dynamic getNativeInfoDiskRatio(Map? nativeInfo) {
    return nativeInfo?['disk_ratio'];
  }

  String? getNativeInfoState(Map? nativeInfo) {
    return nativeInfo?['state'];
  }

  String? getNativeInfoSessionId(Map? nativeInfo) {
    return nativeInfo?['um_session_id'];
  }
}
