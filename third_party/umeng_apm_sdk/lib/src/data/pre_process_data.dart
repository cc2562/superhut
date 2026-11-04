import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

class PreProcessData {
  CommonData? commonLog;
  dynamic log;
  ReportLogType? type;
  String? md5;

  PreProcessData({this.commonLog, this.log, this.type, this.md5});

  Map<String, dynamic> get() {
    return {"common": commonLog, "log": log, 'type': type, 'md5': md5};
  }
}
