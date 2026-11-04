import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一次版本检查的结果。
///
/// 字段与后端 `check_version.php` 的返回一一对应，避免各个页面各写一套解析。
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.description,
    required this.isForced,
    required this.downloadUrl,
  });

  /// 是否存在新版本。
  final bool hasUpdate;

  /// 后端给出的最新版本号。
  final String latestVersion;

  /// 更新说明。
  final String description;

  /// 是否为强制更新（不可跳过、不可忽略）。
  final bool isForced;

  /// 新版本下载地址。
  final String downloadUrl;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final String latest = '${json['latest_version'] ?? ''}'.trim();
    return AppUpdateInfo(
      // 后端字段可能是 bool / 数字 / 字符串，统一按「是否明确表示已是最新」判断。
      hasUpdate: !_asBool(json['is_latest']),
      latestVersion: latest,
      description: '${json['description'] ?? ''}'.trim(),
      isForced: _asBool(json['is_forced']),
      downloadUrl: '${json['download_url'] ?? ''}'.trim(),
    );
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String text = value.trim().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes';
    }
    return false;
  }
}

/// 版本检查与「本版本不再提醒」的本地状态。
///
/// 自动检查与设置页的手动检查共用这里，区别只在于是否读取忽略标记：
/// * 自动检查（每次进入首页）：被忽略的版本不再弹窗；
/// * 手动检查（我的 - 检查更新）：忽略标记不生效，强制更新也照常弹窗。
class AppUpdateService {
  const AppUpdateService._();

  /// 版本检查接口，沿用原有地址，不做改动。
  static const String endpoint = 'https://super.ccrice.com/api/check_version.php';

  /// 已忽略提醒的版本号（只忽略这一个版本，出现更新的版本仍会提醒）。
  static const String skipStorageKey = 'skipped_update_version';

  static Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// 仅供测试替换网络层。
  @visibleForTesting
  static set dio(Dio value) => _dio = value;

  /// 查询最新版本；失败时抛出 [DioException]，由调用方决定如何提示。
  static Future<AppUpdateInfo> fetch(String currentVersion) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      endpoint,
      queryParameters: <String, Object>{'version': currentVersion},
    );
    final Object? data = response.data;
    if (data is! Map) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: '版本接口返回格式异常',
        response: response,
      );
    }
    return AppUpdateInfo.fromJson(Map<String, dynamic>.from(data));
  }

  /// 读取已忽略的版本号；没有忽略过则返回 null。
  static Future<String?> skippedVersion() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = (prefs.getString(skipStorageKey) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  /// 记住「本版本不再提醒」。
  static Future<void> skipVersion(String version) async {
    final String value = version.trim();
    if (value.isEmpty) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(skipStorageKey, value);
  }

  /// 是否应该向用户弹窗。
  ///
  /// 强制更新永远提醒（忽略标记对它无效）；其余版本按「最新版本是否被忽略」判断。
  static bool shouldNotify(AppUpdateInfo info, String? skippedVersion) {
    if (!info.hasUpdate) return false;
    if (info.isForced) return true;
    return info.latestVersion.isEmpty || info.latestVersion != skippedVersion;
  }
}
