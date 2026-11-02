import 'dart:io';

import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 微软 Clarity 行为分析的唯一启动入口。
///
/// 合规要求：**必须等用户在同意页勾选并点击「同意并继续」之后才能启动**，
/// 因此这里提供的是运行时初始化（官方推荐的 `Clarity.initialize`），
/// 而不是在 `main()` 里用 `ClarityWidget` 包住整棵树——那样无法延后到同意之后。
///
/// 未同意时本类不会被调用，不会产生任何采集；同意后再进入应用也只会调用一次
/// （内部有幂等保护）。
class ClarityService {
  const ClarityService._();

  /// Clarity 项目 ID（在 Clarity 仪表盘 Settings 里可查）。
  static const String projectId = 's1q3qmd7zu';

  static bool _started = false;

  /// 当前平台是否能跑 Clarity。
  ///
  /// `clarity_flutter` 只提供 Android / iOS 原生实现，其它平台调用会抛
  /// `MissingPluginException`；测试环境同样不初始化，避免污染 widget 测试
  /// （与 `ThemeController.liquidGlassSupported` 的判定方式保持一致）。
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 启动采集；返回是否真的启动成功。
  ///
  /// 任何失败都只记一条中文日志，绝不影响用户继续使用应用。
  static bool start(BuildContext context) {
    if (_started) return true;
    if (!isSupportedPlatform) {
      debugPrint('Clarity 未启动：当前平台不支持或处于测试环境');
      return false;
    }
    try {
      final bool started = Clarity.initialize(
        context,
        ClarityConfig(
          projectId: projectId,
          // 生产构建里 SDK 会把级别强制压到 None，这里显式写清楚意图：
          // 调试期打开 Verbose 才能看到 [Clarity] 日志。
          logLevel: kDebugMode ? LogLevel.Verbose : LogLevel.None,
        ),
      );
      _started = started;
      if (!started) debugPrint('Clarity 未启动：SDK 初始化返回 false');
      return started;
    } catch (error) {
      debugPrint('Clarity 初始化失败：$error');
      return false;
    }
  }
}
