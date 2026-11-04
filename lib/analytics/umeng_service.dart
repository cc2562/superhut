import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:umeng_apm_sdk/umeng_apm_sdk.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';

/// 友盟（U-App 移动统计 + U-APM 性能监控）的唯一入口。
///
/// 走官方 Flutter 组件：`umeng_common_sdk` 负责统计，`umeng_apm_sdk` 负责
/// Dart 异常、页面性能与帧率；两套原生 SDK 由这两个组件自带，工程里不再单独依赖 AAR。
///
/// 合规要求与 `ClarityService` 一致：
/// * 必须等用户在同意页勾选「使用体验分析」并点击「同意并继续」之后才初始化；
/// * 初始化之前只会有一次「不采集数据」的原生预加载（`preInit`，官方要求），
///   不会有任何上报；
/// * 用户可以在「隐私设置」里随时关闭，关闭后不再发起新的初始化。
class UmengService {
  const UmengService._();

  /// 友盟后台「超级包菜」Android 应用的 AppKey。
  static const String appKey = '6aeac349863270068cb58c1b';

  /// 分发渠道号（友盟后台的渠道维度）。
  static const String channel = 'official';

  /// 本次只接 Android；官方 API 要求两个平台各给一个 AppKey，iOS 留空。
  static const String _iosAppKey = '';

  /// 只用来做一件事：告诉原生「用户已同意隐私政策」。
  static const MethodChannel _nativeConsent = MethodChannel(
    'com.zhiquxy.rice/umeng',
  );

  static bool _started = false;
  static bool _revoked = false;

  /// 当前是否已初始化（不代表正在采集；撤回后仍是 `true`）。
  static bool get isStarted => _started;

  /// 当前平台是否能跑友盟 SDK。
  ///
  /// 本次只接了 Android；Web、桌面端与 `flutter test` 环境一律不调用原生方法，
  /// 避免 `MissingPluginException` 污染现有测试。
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    if (Platform.environment['FLUTTER_TEST'] == 'true') return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// 启动统计与性能采集；返回是否初始化成功。
  ///
  /// 幂等：重复调用不会重复初始化，也不会抛异常。
  static Future<bool> start() async {
    if (_revoked) {
      debugPrint('友盟未启动：用户已关闭使用体验分析');
      return false;
    }
    if (_started) return true;
    if (!isSupportedPlatform) {
      debugPrint('友盟未启动：当前平台不支持或处于测试环境');
      return false;
    }
    try {
      // 1. 先回执隐私授权：原生侧据此调用 submitPolicyGrantResult。
      await _nativeConsent.invokeMethod<bool>('grantConsent');
      // 2. 移动统计：公共底座 + U-App 一起完成初始化。
      //
      // 官方组件的原生实现只执行 init、不回传结果，`await` 会永远挂起
      // （这也是之前 APM 一直没被初始化、Dart 异常一条都收不到的原因）。
      // 这里只发起、不等待，随后由 APM 侧自行等待原生就绪。
      unawaited(
        UmengCommonSdk.initCommon(appKey, _iosAppKey, channel).catchError(
          (Object error) {
            debugPrint('友盟统计初始化异常：$error');
            return null;
          },
        ),
      );
      // 3. 性能监控：Dart 异常、页面性能、帧率。
      await _startApm();
      _started = true;
      return true;
    } catch (error) {
      debugPrint('友盟初始化失败：$error');
      return false;
    }
  }

  /// 与 [start] 同义，供设置页开关复用。
  static Future<bool> enable() => start();

  /// 撤回同意：此后不再发起初始化。
  ///
  /// 友盟 SDK 没有运行期暂停接口，所以这里不做「停止上报」的假承诺：
  /// 生效点是下一次冷启动——那时 [start] 会因为撤回标记而不再初始化。
  static Future<void> withdraw() async {
    _revoked = true;
    debugPrint('友盟：已停止后续初始化，下次冷启动不再启动采集');
  }

  /// 初始化 U-APM 的 Flutter 侧采集。
  ///
  /// 原生崩溃 / ANR 由 `SuperhutApplication` 里的 `UMCrash.initConfig` 负责，
  /// 这里只负责 Dart 层：异常、页面耗时、帧率。
  static Future<void> _startApm() async {
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (error) {
      debugPrint('友盟 APM 未取到应用版本，使用兜底值：$error');
    }
    final String version = info?.version ?? '';
    final String build = info?.buildNumber ?? '';
    final String bver = version.isEmpty
        ? 'unknown'
        : (build.isEmpty ? version : '$version+$build');
    UmengApmSdk(
      name: info?.appName.isNotEmpty == true ? info!.appName : 'superhut',
      bver: bver,
      env: UmengApmEnv.Release,
      // 正式包默认静默；排查线上问题时可用 --dart-define=umengApmLog=true 临时打开。
      enableLog: kDebugMode || const bool.fromEnvironment('umengApmLog'),
      enableTrackingPageFps: true,
      enableTrackingPagePerf: true,
      // 必须保持关闭：开启后组件会安装全局 HttpOverrides 记录每个请求的完整 URL，
      // 而本应用把学号/密码、手机号/验证码放在 query string 里（见 HutUserApi），
      // 这些凭据会被原样上报到友盟。宁可少一项网络性能指标，也不能泄露凭据。
      enableTrackingApi: false,
      // 组件的 ensureInitialized 每次都会 new 一个新绑定，重复调用会直接断言失败。
      // 启动时（main）已经用 ApmWidgetsFlutterBinding 初始化过，这里不再重复创建。
      initFlutterBinding: () {},
    ).init();
  }

  /// 转发应用级未捕获的异步错误到 U-APM。
  ///
  /// 组件内部的 `runZonedGuarded` 只包住传入 `appRunner` 的场景；本应用要等用户同意
  /// 才初始化，那时 `runApp` 早已在根 zone 执行完毕，无法再被包进去。
  /// 因此由 `main` 注册 `PlatformDispatcher.onError` 兜住根 zone 的错误，转到这里上报。
  ///
  /// 未初始化（未同意或已撤回）时直接丢弃，避免绕过同意门控。
  static void reportUncaughtError(Object error, StackTrace stack) {
    if (!_started || _revoked) return;
    try {
      ExceptionTrace.zonedGuardedErrorHandler(exception: error, stack: stack);
    } catch (reportError) {
      debugPrint('友盟未捕获异常上报失败：$reportError');
    }
  }

  /// 供测试查看撤回状态。
  @visibleForTesting
  static bool get isRevoked => _revoked;

  /// 仅供测试重置内部状态，避免用例之间互相影响。
  @visibleForTesting
  static void resetForTest() {
    _started = false;
    _revoked = false;
  }
}
