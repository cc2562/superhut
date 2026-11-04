import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/processor/common_data_processor.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

class ApiDataProcessor extends CommonDataProcessor {
  CommonData? commonLog;

  ApiDataProcessor(Map? nativeInfo) {
    nativeInfo ??= {};
    commonLog = super.createCommonData('api', nativeInfo);
  }

  void push({required ApiData apiData}) {
    nativeTryCatch(handler: () {
      final preProcessData = createPreProcessData(apiData);
      addPreProcessData(preProcessData);
      super.commonData = commonLog;
    });
  }

  void addPreProcessData(PreProcessData preProcessData) {
    this.pushLogToQueue(
      reportType: ReportLogType.api,
      reportQueueType: ReportQueueType.pre,
      log: preProcessData,
    );
  }

  PreProcessData createPreProcessData(ApiData apiData) {
    return PreProcessData(
      commonLog: commonLog,
      log: apiData,
      type: ReportLogType.api,
    );
  }
}