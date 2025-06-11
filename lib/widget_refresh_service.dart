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
      final bool result = await _channel.invokeMethod(
        'refreshCourseTableWidget',
      );
      return result;
    } on PlatformException catch (e) {
      print('刷新小组件失败: ${e.message}');
      return false;
    }
  }
}
