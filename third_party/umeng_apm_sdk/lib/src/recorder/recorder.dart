import 'package:umeng_apm_sdk/src/recorder/page_fps_recorder.dart';
import 'package:umeng_apm_sdk/src/recorder/page_perf_recorder.dart';
import 'package:umeng_apm_sdk/src/recorder/request_recorder.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';

class ApmRecorder {
  ApmRecorder();

  static void init() {
    PagePerfRecorder();
    PageFpsRecorder();
    if (enableTrackingApi() == true){
      RequestRecorder();
    }
  }

  static bool enableTrackingApi() {
    return GlobalStore.singleInstance.getStore['enableTrackingApi'] ??
        false;
  }

}
