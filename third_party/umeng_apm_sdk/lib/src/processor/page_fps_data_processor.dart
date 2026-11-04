import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/processor/common_data_processor.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';

class PageFpsDataProcessor extends CommonDataProcessor {
  CommonData? commonLog;

  PageFpsDataProcessor(Map? nativeInfo) {
    nativeInfo ??= {};
    commonLog = super.createCommonData('page_fps', nativeInfo);
  }

  void push({required PageFpsData pageFpsData}) {
    nativeTryCatch(handler: () {
      final preProcessData = createPreProcessData(pageFpsData);
      addPreProcessData(preProcessData);
      super.commonData = commonLog;
    });
  }

  void addPreProcessData(PreProcessData preProcessData) {
    this.pushLogToQueue(
      reportType: ReportLogType.page_fps,
      reportQueueType: ReportQueueType.pre,
      log: preProcessData,
    );
  }

  PreProcessData createPreProcessData(PageFpsData pageFpsData) {
    return PreProcessData(
      commonLog: commonLog,
      log: pageFpsData,
      type: ReportLogType.page_fps,
    );
  }
}
