import 'package:flutter/widgets.dart';
import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/event/router_event.dart';
import 'package:umeng_apm_sdk/src/core/apm_performance.dart';

class ApmNavigatorObserver extends NavigatorObserver {
  ApmNavigatorObserver() {
    _instance = this;
  }

  static ApmNavigatorObserver? _instance;

  static ApmNavigatorObserver get singleInstance =>
      _instance ??= ApmNavigatorObserver();

  @override
  void didPush(Route route, Route? previousRoute) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.push, route, previousRoute));
    });
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.replace, newRoute, oldRoute));
    });
  }

  // 路由从导航栈被弹出时
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.pop, route, previousRoute));
    });
  }

  // 路由从导航栈被移除时
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    nativeTryCatch(handler: () {
      ApmPerformance.singleInstance
          .pushEvent(RouterEvent(RouterEventType.remove, route, previousRoute));
    });
  }
}
