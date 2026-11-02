import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/security/credential_store.dart';

/// 模拟「换机 / 系统升级后 KeyStore 失效」：任何操作都抛异常。
class _BrokenSecureStorage extends FlutterSecureStoragePlatform {
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => throw StateError('keystore unavailable');

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('keystore unavailable');

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('keystore unavailable');

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('keystore unavailable');

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => throw StateError('keystore unavailable');

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      throw StateError('keystore unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    CredentialStore.instance.clearCacheForTest();
  });

  tearDown(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    CredentialStore.instance.clearCacheForTest();
  });

  test('敏感键按名单与后缀识别', () {
    expect(CredentialStore.isSensitiveKey('user'), isTrue);
    expect(CredentialStore.isSensitiveKey('password'), isTrue);
    expect(CredentialStore.isSensitiveKey('hutToken'), isTrue);
    expect(CredentialStore.isSensitiveKey('hutRefreshToken'), isTrue);
    // 动态键：教务 token / cookie、饮水 token 都靠后缀命中。
    expect(CredentialStore.isSensitiveKey('jwxt_token'), isTrue);
    expect(CredentialStore.isSensitiveKey('my_client_ticket'), isTrue);
    expect(CredentialStore.isSensitiveKey('some_cookie'), isTrue);

    // 展示型缓存与非敏感设置不进安全存储。
    expect(CredentialStore.isSensitiveKey('name'), isFalse);
    expect(CredentialStore.isSensitiveKey('academyName'), isFalse);
    expect(CredentialStore.isSensitiveKey('isFirstOpen'), isFalse);
  });

  test('迁移把明文凭据搬进安全存储并删除原键', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user': '20230001',
      'password': 'secret',
      'token': 'jwxt-token',
      'my_client_ticket': 'cookie-value',
      'name': '张三',
      'entranceYear': '2023',
    });

    await CredentialStore.instance.migrateFromPrefs();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // 敏感键被移出 prefs（明文不再落盘）。
    expect(prefs.getString('user'), isNull);
    expect(prefs.getString('password'), isNull);
    expect(prefs.getString('token'), isNull);
    expect(prefs.getString('my_client_ticket'), isNull);
    expect(prefs.getBool('credentials.migratedV2'), isTrue);
    // 展示型缓存放回原地。
    expect(prefs.getString('name'), '张三');
    expect(prefs.getString('entranceYear'), '2023');

    // 值被完整搬到安全存储。
    expect(await CredentialStore.instance.read('user'), '20230001');
    expect(await CredentialStore.instance.read('password'), 'secret');
    expect(await CredentialStore.instance.read('token'), 'jwxt-token');
    expect(
      await CredentialStore.instance.read('my_client_ticket'),
      'cookie-value',
    );
  });

  test('迁移是幂等的：有标记后不再二次搬运', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user': '20230001',
      'password': 'secret',
    });
    await CredentialStore.instance.migrateFromPrefs();

    // 模拟老代码又把明文写回 prefs（例如未清理的旧版本逻辑）。
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', 'should-stay');

    CredentialStore.instance.clearCacheForTest();
    await CredentialStore.instance.migrateFromPrefs();

    // 迁移标记存在 -> 直接跳过，新写入的明文保持原样（不会被误当成待迁移数据）。
    expect(prefs.getString('user'), 'should-stay');
    expect(await CredentialStore.instance.read('user'), '20230001');
  });

  test('安全存储不可用时按「无凭据」降级，不抛异常', () async {
    FlutterSecureStoragePlatform.instance = _BrokenSecureStorage();
    CredentialStore.instance.clearCacheForTest();

    expect(await CredentialStore.instance.read('user'), isNull);
    // 写入失败也不抛：本次会话内存里仍然有新值。
    await expectLater(
      CredentialStore.instance.write('user', '20230001'),
      completes,
    );
    expect(await CredentialStore.instance.read('user'), '20230001');
    await expectLater(CredentialStore.instance.delete('user'), completes);
    await expectLater(CredentialStore.instance.clearSensitive(), completes);
  });

  test('clearSensitive 清空缓存与安全存储', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'user': '20230001',
      'token': 'jwxt-token',
    });
    CredentialStore.instance.clearCacheForTest();
    expect(await CredentialStore.instance.read('user'), '20230001');

    await CredentialStore.instance.clearSensitive();

    expect(await CredentialStore.instance.read('user'), isNull);
    expect(await CredentialStore.instance.read('token'), isNull);
  });
}
