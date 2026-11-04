import 'dart:async';
import 'package:flutter/material.dart';

import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

class ApmScrollController extends ScrollController {
  // 注册定时器
  Timer _registerTimer({required int seconds, required Function callback}) {
    return Timer(Duration(seconds: seconds), () {
      callback();
    });
  }

  Timer? _timer;

  void _setAppStatus({required int statusCode}) {
    GlobalStore.singleInstance
        .setProperty(name: KEY_APP_STATUS, value: statusCode);
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _setAppStatus(statusCode: 2);
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    position.isScrollingNotifier.addListener(_handleScrolling);
  }

  @override
  void detach(ScrollPosition position) {
    position.isScrollingNotifier.removeListener(_handleScrolling);
    super.detach(position);
  }

  void _handleScrolling() {
    if (position.isScrollingNotifier.value) {
      _timer?.cancel();
      _setAppStatus(statusCode: 1);
    } else {
      // 考虑滑动阻尼效果和存在分页绘制等情况 默认延长2s 作为scroll状态记录应用状态
      // 延迟两秒执行任务
      _timer = _registerTimer(
          seconds: 2,
          callback: () {
            // 延迟执行的任务
            _setAppStatus(statusCode: 2);
          });
    }
  }
}
