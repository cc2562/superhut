import 'package:flutter/widgets.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/event/render_event.dart';
import 'package:umeng_apm_sdk/src/core/apm_performance.dart';
import 'package:umeng_apm_sdk/src/event/app_lifecycle_event.dart';

class ApmWidgetsFlutterBinding extends WidgetsFlutterBinding {
  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    print('AppLifecycleState changed to $state');

    super.handleAppLifecycleStateChanged(state);

    if (state == AppLifecycleState.paused) {
      nativeTryCatch(handler: () {
        // 监听应用退至后台
        ApmPerformance.singleInstance
            .pushEvent(ApmAppLifecycleEvent(ApmAppLifecycleState.paused));
      });
    }
  }

  @override
  void handleDrawFrame() {
    super.handleDrawFrame();
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance.pushEvent(ApmRenderEvent(
          ApmRenderEventType.endFrame,
          renderObject: renderView));
    });
  }

  static WidgetsBinding? ensureInitialized() {
    ApmWidgetsFlutterBinding();
    return WidgetsBinding.instance;
  }
}
