import 'package:flutter/widgets.dart';

import '../analytics/clarity_service.dart';

/// 设置页依赖的最小行为分析接口。
///
/// 生产实现直接委托 [ClarityService]；测试可以注入 fake，
/// 从而在不加载原生 SDK 的前提下断言「开关 -> 采集状态」的调用关系。
abstract interface class AnalyticsRecorder {
  /// 开启采集；[context] 必须是位于 `MaterialApp` 之内、带 `MediaQuery` 的 context。
  Future<void> enable(BuildContext context);

  /// 停止采集。
  Future<void> withdraw();
}

/// 默认实现：Microsoft Clarity。
class ClarityAnalyticsRecorder implements AnalyticsRecorder {
  const ClarityAnalyticsRecorder();

  @override
  Future<void> enable(BuildContext context) async {
    ClarityService.enable(context);
  }

  @override
  Future<void> withdraw() async {
    ClarityService.withdraw();
  }
}
