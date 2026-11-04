import 'package:flutter/foundation.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

import 'umeng_service.dart';

/// 友盟自定义事件的预留入口。
///
/// 目前只做自动采集（启动、活跃、崩溃、卡顿、页面性能），
/// **没有在任何业务页面里埋点**。将来要加业务事件时改这一处即可，
/// 不必把友盟的调用散落到页面里。
///
/// 约定：
/// * 只在 [UmengService] 已初始化（即用户已同意）之后才上报；
/// * 参数只支持字符串与数值，其他类型直接丢弃（友盟侧的硬限制）。
class UmengEventTracker {
  const UmengEventTracker._();

  /// 上报一个自定义事件；返回是否真的发出。
  ///
  /// [params] 只允许 String / int / double，嵌套结构会被丢弃。
  static bool track(String eventId, [Map<String, Object?>? params]) {
    final String id = eventId.trim();
    if (id.isEmpty) {
      debugPrint('友盟事件未上报：eventId 为空');
      return false;
    }
    if (!UmengService.isStarted) {
      debugPrint('友盟事件未上报：SDK 尚未初始化（用户未同意或平台不支持）');
      return false;
    }
    try {
      UmengCommonSdk.onEvent(id, _sanitize(params));
      return true;
    } catch (error) {
      debugPrint('友盟事件上报失败：$error');
      return false;
    }
  }

  /// 剔除友盟不支持的参数类型，避免被静默丢弃或报错。
  static Map<String, dynamic> _sanitize(Map<String, Object?>? params) {
    final Map<String, dynamic> result = <String, dynamic>{};
    if (params == null) return result;
    params.forEach((key, value) {
      if (key.trim().isEmpty) return;
      if (value is String || value is int || value is double) {
        result[key] = value;
      }
    });
    return result;
  }
}
