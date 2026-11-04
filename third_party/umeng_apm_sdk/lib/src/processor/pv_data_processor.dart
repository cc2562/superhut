import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/processor/common_data_processor.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';

class PvDataProcessor extends CommonDataProcessor {
  push({required PvData pvData, Map? nativeInfo}) {
    nativeTryCatch(handler: () {
      nativeInfo ??= {};
      super.commonData = super.createCommonData('pv', nativeInfo);
      PreProcessData preProcessData = PreProcessData(
          commonLog: super.commonData, log: pvData, type: ReportLogType.pv);
      this.pushLogToQueue(
          reportType: ReportLogType.pv,
          reportQueueType: ReportQueueType.pre,
          log: preProcessData);
    });
  }
}
