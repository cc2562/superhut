import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录凭据与会话令牌的唯一读写口。
///
/// 背景：这些数据以前直接写在 SharedPreferences 里——那是明文 XML/plist，
/// 只要能读到应用沙箱就能拿到用户的学号密码。现在统一走系统安全存储：
/// Android 用 Keystore 包装密钥（AES-GCM + RSA-OAEP），iOS 用 Keychain。
///
/// 三个设计要点：
/// * **内存缓存**：`configureDioFromStorage` 这类每次请求都要 token 的地方，
///   不能每次都真的去问 Keystore/Keychain（单次 1–10ms），首次读到后缓存住。
/// * **先写后删的迁移**：老版本已经把明文写进 prefs 了，升级时要搬过来再删原键，
///   中途失败宁可留重复数据，也不能丢凭据。
/// * **失败降级**：安全存储读失败（少数机型系统升级后 KeyStore 失效）按「没有凭据」
///   处理，让用户重新登录，绝不抛异常打断启动。
class CredentialStore {
  CredentialStore._();

  static final CredentialStore instance = CredentialStore._();

  /// iOS 端用 `first_unlock_this_device`：开机首次解锁后可读，且不随备份迁移到新设备。
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Android 侧：v10 起默认就是 AES-GCM 加密数据 + RSA-OAEP 包装密钥，
  /// 旧的 `encryptedSharedPreferences` 参数已被官方标记废弃并忽略
  /// （Jetpack Security 停止维护），因此不再显式传它。
  static const AndroidOptions _androidOptions = AndroidOptions();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: _iosOptions,
    aOptions: _androidOptions,
  );

  /// key -> 值（读过的键才在表里，null 表示「确实不存在」）。
  final Map<String, String?> _cache = <String, String?>{};

  static const String _migrationFlagKey = 'credentials.migratedV2';

  /// 明确需要进安全存储的键。
  static const Set<String> sensitiveKeys = <String>{
    'user',
    'password',
    'token',
    'hutToken',
    'hutRefreshToken',
    'hutUsername',
    'hutPassword',
    'hutAccount',
    'deviceId',
    'hutMobile',
    'hutUserInfo',
    'loginPostToken',
    'my_client_ticket',
  };

  /// 动态键（教务 token/cookie、饮水 token 等）靠后缀识别。
  static const List<String> _sensitiveSuffixes = <String>[
    'token',
    'cookie',
    'ticket',
    'password',
  ];

  /// 是否属于需要加密存储的键。
  static bool isSensitiveKey(String key) {
    if (sensitiveKeys.contains(key)) return true;
    final String lower = key.toLowerCase();
    return _sensitiveSuffixes.any(lower.endsWith);
  }

  /// 读取；不存在或读取失败都返回 null（并缓存，避免重复失败重试）。
  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final String? value = await _storage.read(key: key);
      _cache[key] = value;
      return value;
    } catch (error) {
      debugPrint('安全存储读取失败（$key）：$error');
      _cache[key] = null;
      return null;
    }
  }

  /// 读取空串兜底，省掉调用处的 `?? ''`。
  Future<String> readOrEmpty(String key) async => await read(key) ?? '';

  Future<void> write(String key, String value) async {
    _cache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (error) {
      // 写失败时内存里仍是新值，本次使用不受影响；下次启动会退回旧值或要求重登。
      debugPrint('安全存储写入失败（$key）：$error');
    }
  }

  Future<void> delete(String key) async {
    _cache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (error) {
      debugPrint('安全存储删除失败（$key）：$error');
    }
  }

  /// 仅用于测试：清掉内存缓存，让下一次读取真的去问（已 mock 的）安全存储。
  @visibleForTesting
  void clearCacheForTest() => _cache.clear();

  /// 退出登录时清空全部凭据（含动态键，所以直接 deleteAll）。
  ///
  /// 注意：安全存储里只有凭据，主题 / 外观 / 协议同意这些非敏感设置都在
  /// SharedPreferences，不会被这里波及。
  Future<void> clearSensitive() async {
    _cache.clear();
    try {
      await _storage.deleteAll();
    } catch (error) {
      debugPrint('清空安全存储失败：$error');
    }
  }

  /// 把 SharedPreferences 里残留的明文凭据搬进安全存储，并删除原键。
  ///
  /// 幂等：完成后写 `credentials.migratedV2` 标记，重复启动直接跳过。
  /// 顺序是「先写安全存储成功、再删 prefs」，失败最多留下重复数据。
  Future<void> migrateFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationFlagKey) == true) return;

      final List<String> migrated = <String>[];
      for (final String key in prefs.getKeys().toList()) {
        if (!isSensitiveKey(key)) continue;
        final Object? value = prefs.get(key);
        if (value is! String || value.isEmpty) continue;
        await _storage.write(key: key, value: value);
        _cache[key] = value;
        migrated.add(key);
      }

      for (final String key in migrated) {
        await prefs.remove(key);
      }
      await prefs.setBool(_migrationFlagKey, true);
      if (migrated.isNotEmpty) {
        debugPrint('已迁移 ${migrated.length} 项本地凭据到安全存储');
      }
    } catch (error) {
      debugPrint('凭据迁移失败，将在下次启动重试：$error');
    }
  }
}
