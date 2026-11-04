import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 课程实时活动的两个阶段。
enum ClassLiveActivityPhase {
  /// 上课前 10 分钟窗口内：倒计时到上课时间。
  preClass,

  /// 正在上课：倒计时到下课时间。
  inClass,
}

extension ClassLiveActivityPhaseX on ClassLiveActivityPhase {
  /// 传给原生的阶段标识，与 Swift 侧的 `phase` 字符串保持一致。
  String get wireValue =>
      this == ClassLiveActivityPhase.preClass ? 'pre' : 'inClass';
}

/// 一次实时活动的全部参数。
///
/// 课程数据随 `Activity.request` / `update` 一起传给 Widget，
/// 不走 App Group，避免无签名 IPA 自签后 entitlement 缺失导致读不到数据。
class ClassLiveActivityRequest {
  const ClassLiveActivityRequest({
    required this.courseId,
    required this.courseName,
    required this.location,
    required this.start,
    required this.end,
    required this.phase,
  });

  final String courseId;
  final String courseName;
  final String location;
  final DateTime start;
  final DateTime end;
  final ClassLiveActivityPhase phase;

  Map<String, Object> toMap() => <String, Object>{
    'courseId': courseId,
    'courseName': courseName,
    'location': location,
    'startTimeMs': start.millisecondsSinceEpoch,
    'endTimeMs': end.millisecondsSinceEpoch,
    'phase': phase.wireValue,
  };
}

/// iOS 实时活动（灵动岛 / 锁屏卡片）的唯一原生入口。
///
/// 只有 iOS 才有 ActivityKit；这里用 [defaultTargetPlatform] 而不是
/// `Platform.isIOS`，既能避开 Web，也让 widget 测试可以用
/// `debugDefaultTargetPlatformOverride` 覆盖平台。
///
/// 所有调用都可失败：原生未注册、系统未授权、低版本 iOS 一律返回 false，
/// 由调用方当作「本次不展示」，不影响课表与其它提醒。
class ClassLiveActivityService {
  const ClassLiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.zhiquxy.rice/live_activity',
  );

  static bool get isPlatformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 系统是否允许实时活动（用户可能在设置里关掉了「实时活动」）。
  static Future<bool> isSupported() async {
    if (!isPlatformSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (error) {
      debugPrint('实时活动能力探测失败：${error.message}');
      return false;
    } catch (error) {
      debugPrint('实时活动能力探测失败：$error');
      return false;
    }
  }

  static Future<bool> start(ClassLiveActivityRequest request) async {
    return _invoke('start', request.toMap());
  }

  static Future<bool> update(ClassLiveActivityRequest request) async {
    return _invoke('update', request.toMap());
  }

  static Future<bool> end(String courseId) async {
    return _invoke('end', <String, Object>{'courseId': courseId});
  }

  static Future<bool> _invoke(
    String method,
    Map<String, Object> arguments,
  ) async {
    if (!isPlatformSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException catch (error) {
      debugPrint('实时活动 $method 失败：${error.message}');
      return false;
    } catch (error) {
      debugPrint('实时活动 $method 失败：$error');
      return false;
    }
  }
}
