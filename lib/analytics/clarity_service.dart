import 'dart:io';

import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Clarity 的采集状态。
enum ClarityCaptureState {
  /// 还没初始化（未同意、平台不支持或初始化失败）。
  off,

  /// 正在采集。
  active,

  /// 已初始化但处于暂停状态（用户撤回了同意）。
  paused,
}

/// 微软 Clarity 行为分析的唯一入口。
///
/// 合规要求：
/// * **必须等用户在同意页勾选「行为分析」并点击「同意并继续」之后才能启动**；
/// * 用户可以在「隐私设置」里随时关闭，关闭后立即暂停采集。
///
/// 因此这里提供的是运行时初始化（官方推荐的 `Clarity.initialize`），
/// 而不是在 `main()` 里用 `ClarityWidget` 包住整棵树——那样无法延后到同意之后。
///
/// 所有方法都是幂等的：重复调用不会重复初始化，也不会抛异常。
class ClarityService {
  const ClarityService._();

  /// Clarity 项目 ID（在 Clarity 仪表盘 Settings 里可查）。
  static const String projectId = 's1q3qmd7zu';

  static bool _started = false;

  /// 当前是否已初始化（不代表正在采集，撤回后仍是 `true`）。
  static bool get isStarted => _started;

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

  /// 当前采集状态。
  static ClarityCaptureState get state {
    if (!_started) return ClarityCaptureState.off;
    try {
      return Clarity.isPaused()
          ? ClarityCaptureState.paused
          : ClarityCaptureState.active;
    } catch (error) {
      debugPrint('Clarity 状态读取失败：$error');
      return ClarityCaptureState.paused;
    }
  }

  /// 启动采集；返回是否真的启动成功。
  ///
  /// `context` 必须位于 `MaterialApp` 之内并带 `MediaQuery`（例如同意页、
  /// 设置页的 context），否则 SDK 会拒绝初始化。
  ///
  /// 任何失败都只记一条中文日志，绝不影响用户继续使用应用。
  static bool start(BuildContext context) {
    if (_started) {
      // 已初始化：只需确保同意状态与采集状态都是「开启」。
      return _applyConsent(true);
    }
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
      if (!started) {
        debugPrint('Clarity 未启动：SDK 初始化返回 false');
        return false;
      }
      return _applyConsent(true);
    } catch (error) {
      debugPrint('Clarity 初始化失败：$error');
      return false;
    }
  }

  /// 开启采集（已初始化则直接恢复并更新同意状态）。
  static bool enable(BuildContext context) {
    if (!_started) return start(context);
    return _applyConsent(true);
  }

  /// 撤回同意：暂停采集并撤销 SDK 侧的同意标记。
  ///
  /// 已初始化时才调用，未初始化意味着本来就没有采集。
  static void withdraw() {
    if (!_started) return;
    try {
      Clarity.pause();
    } catch (error) {
      debugPrint('Clarity 暂停失败：$error');
    }
    _applyConsent(false);
  }

  /// 把同意状态同步给 SDK。
  ///
  /// `adsStorage` 恒为 `false`：本应用不投放广告，也不做广告用途的数据分析，
  /// 隐私政策里也是这么承诺的——不能为了「少一次调用」而多要一项同意。
  static bool _applyConsent(bool allowed) {
    try {
      // 顺序无关紧要，但先给同意再恢复能避免恢复后被判定为无同意采集。
      final bool consented = Clarity.consent(false, allowed);
      if (!allowed) return consented;
      final bool resumed = Clarity.resume();
      return consented || resumed;
    } catch (error) {
      debugPrint('Clarity 同意状态同步失败：$error');
      return false;
    }
  }
}
