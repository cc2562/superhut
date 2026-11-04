import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/processor/common_data_processor.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';

class PagePerfDataProcessor extends CommonDataProcessor {
  CommonData? commonLog;

  PagePerfDataProcessor(Map? nativeInfo) {
    nativeInfo ??= {};
    commonLog = createCommonData('page_perf', nativeInfo);
  }

  void push({required PagePerfData pagePerfData}) {
    nativeTryCatch(handler: () {
      pushLogToQueue(
        reportType: ReportLogType.page_perf,
        reportQueueType: ReportQueueType.pre,
        log: PreProcessData(
          commonLog: commonLog,
          log: pagePerfData,
          type: ReportLogType.page_perf,
        ),
      );
      super.commonData = commonLog;
    });
  }
}
