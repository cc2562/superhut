import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 小组件刷新服务类
/// 用于刷新桌面小组件
class WidgetRefreshService {
  static const MethodChannel _channel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  /// 刷新课程表小组件
  static Future<bool> refreshCourseTableWidget() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'refreshCourseTableWidget',
      );
      return result ?? false;
    } on MissingPluginException catch (e) {
      debugPrint('当前平台未注册课程表小组件刷新通道: $e');
      return false;
    } on PlatformException catch (e) {
      debugPrint('刷新小组件失败: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('刷新小组件时发生异常: $e');
      return false;
    }
  }
}
