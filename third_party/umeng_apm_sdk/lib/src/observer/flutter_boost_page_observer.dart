import 'package:flutter/widgets.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/event/router_event.dart';
import 'package:umeng_apm_sdk/src/core/apm_performance.dart';
import 'package:umeng_apm_sdk/src/event/app_lifecycle_event.dart';

mixin ApmFlutterBoostPageObserver {
  void onPagePush(Route<dynamic> route) {
    nativeTryCatch(handler: () {
      GlobalStore.singleInstance
          .setProperty(name: KEY_USE_BOOST_PLUGIN, value: 1);
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.push, route, null));
    });
  }

  void onPageShow(Route<dynamic> route) {}

  void onPageHide(Route<dynamic> route) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.remove, route, null));
    });
  }

  void onPagePop(Route<dynamic> route) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.pop, route, null));
    });
  }

  void onForeground(Route<dynamic> route) {}

  void onBackground(Route<dynamic> route) {
    nativeTryCatch(handler: () {
      // 监听应用退至后台
      ApmPerformance.singleInstance
          .pushEvent(ApmAppLifecycleEvent(ApmAppLifecycleState.paused));
    });
  }
}
