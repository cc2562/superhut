import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/security/credential_store.dart';
import 'package:superhut/utils/hut_user_api.dart';

String _buildJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const signature = 'sig';
  return '$header.$body.$signature';
}

/// 按「敏感 / 非敏感」把种子数据放进对应的存储：
/// 凭据进 mock 的安全存储，其余留在 SharedPreferences。
void _seed(Map<String, Object> values) {
  final Map<String, Object> prefs = <String, Object>{};
  final Map<String, String> secure = <String, String>{};
  values.forEach((String key, Object value) {
    if (CredentialStore.isSensitiveKey(key)) {
      secure[key] = value.toString();
    } else {
      prefs[key] = value;
    }
  });
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues(secure);
  CredentialStore.instance.clearCacheForTest();
}

Future<String?> _credential(String key) => CredentialStore.instance.read(key);

void main() {
  setUp(() {
    _seed(<String, Object>{});
  });

  group('_completeSmsLoginFromResponseData clears old password creds', () {
    test(
      'removes hutUsername/hutPassword and marks hutAuthMethod=sms',
      () async {
        // Simulate a prior password login.
        _seed({
          'hutUsername': 'olduser',
          'hutPassword': 'oldpass',
          'hutAuthMethod': kHutAuthMethodPassword,
          'hutToken': 'stale',
        });
        final idToken = _buildJwt({
          'sub': '20260001',
          'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
        });
        final rawIdToken = ' $idToken ';

        final api = HutUserApi();
        final result = await api.completeSmsLoginFromResponseData(
          responseData: {
            'code': 0,
            'data': {'idToken': rawIdToken, 'refreshToken': 'new-ref'},
          },
          mobile: '13800138000',
          deviceId: 'dev-1',
        );

        expect(result.success, isTrue);
        // 凭据进安全存储，登录标记与认证方式留 prefs。
        expect(await _credential('hutToken'), rawIdToken);
        expect(await _credential('hutRefreshToken'), 'new-ref');
        expect(await _credential('hutAccount'), '20260001');
        expect(await _credential('deviceId'), 'dev-1');
        expect(await _credential('hutMobile'), '13800138000');
        expect(await _credential('hutUsername'), isNull);
        expect(await _credential('hutPassword'), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
        expect(prefs.getBool('hutIsLogin'), isTrue);
      },
    );
  });

  group('checkTokenValidity SMS branch', () {
    test('returns false when token is empty', () async {
      _seed({'hutAuthMethod': kHutAuthMethodSms});
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test('returns false for an expired JWT', () async {
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      _seed({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': _buildJwt({'exp': pastExp}),
      });
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test('returns false for a corrupted/non-JWT token', () async {
      _seed({'hutAuthMethod': kHutAuthMethodSms, 'hutToken': 'not-a-jwt'});
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test(
      'returns server verdict for a fresh SMS token using hutAccount',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        _seed({
          'hutAuthMethod': kHutAuthMethodSms,
          'hutToken': token,
          'hutAccount': '20260001',
          'deviceId': 'sms-device',
        });

        final api = HutUserApi(
          onlineTokenValidator: ({
            required token,
            required account,
            required deviceId,
          }) async {
            expect(token, _buildJwt({'sub': '20260001', 'exp': futureExp}));
            expect(account, '20260001');
            expect(deviceId, 'sms-device');
            return false;
          },
        );

        expect(await api.checkTokenValidity(), isFalse);
      },
    );

    test('returns false when a SMS session has no persisted account', () async {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': 'unpersisted-account', 'exp': futureExp});
      var validatorCalled = false;
      _seed({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': token,
        'deviceId': 'sms-device',
      });

      final api = HutUserApi(
        onlineTokenValidator: ({
          required token,
          required account,
          required deviceId,
        }) async {
          validatorCalled = true;
          return true;
        },
      );

      expect(await api.checkTokenValidity(), isFalse);
      expect(validatorCalled, isFalse);
    });
  });

  group('refreshToken SMS degrades safely', () {
    test('clears login state but keeps hutMobile when token invalid', () async {
      _seed({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': 'not-a-jwt',
        'hutRefreshToken': 'ref',
        'hutAccount': '20260001',
        'hutMobile': '13800138000',
        'hutIsLogin': true,
      });

      final ok = await HutUserApi().refreshToken();
      expect(ok, isFalse);

      expect(await _credential('hutToken'), isNull);
      expect(await _credential('hutRefreshToken'), isNull);
      expect(await _credential('hutAccount'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hutAuthMethod'), isNull);
      expect(prefs.getBool('hutIsLogin'), isFalse);
      // Mobile preserved so the user can re-request a code without retyping.
      expect(await _credential('hutMobile'), '13800138000');
    });

    test(
      'clears SMS auth state when the server rejects a fresh token',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        _seed({
          'hutAuthMethod': kHutAuthMethodSms,
          'hutToken': token,
          'hutRefreshToken': 'ref',
          'hutAccount': '20260001',
          'hutMobile': '13800138000',
          'hutIsLogin': true,
        });

        final api = HutUserApi(
          onlineTokenValidator:
              ({required token, required account, required deviceId}) async =>
                  false,
        );

        expect(await api.refreshToken(), isFalse);
        expect(await _credential('hutToken'), isNull);
        expect(await _credential('hutRefreshToken'), isNull);
        expect(await _credential('hutAccount'), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutAuthMethod'), isNull);
        expect(prefs.getBool('hutIsLogin'), isFalse);
        expect(await _credential('hutMobile'), '13800138000');
      },
    );

    test(
      'keeps SMS auth state when the server accepts a fresh token',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        _seed({
          'hutAuthMethod': kHutAuthMethodSms,
          'hutToken': token,
          'hutRefreshToken': 'ref',
          'hutAccount': '20260001',
          'hutMobile': '13800138000',
          'hutIsLogin': true,
        });

        final api = HutUserApi(
          onlineTokenValidator:
              ({required token, required account, required deviceId}) async =>
                  true,
        );

        expect(await api.refreshToken(), isTrue);
        expect(await _credential('hutToken'), token);
        expect(await _credential('hutRefreshToken'), 'ref');
        expect(await _credential('hutAccount'), '20260001');
        expect(await _credential('hutMobile'), '13800138000');
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
        expect(prefs.getBool('hutIsLogin'), isTrue);
      },
    );

    test('preserves SMS auth state when online validation throws', () async {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
      _seed({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': token,
        'hutRefreshToken': 'ref',
        'hutAccount': '20260001',
        'hutMobile': '13800138000',
        'hutIsLogin': true,
      });

      final api = HutUserApi(
        onlineTokenValidator:
            ({required token, required account, required deviceId}) async =>
                throw StateError('offline'),
      );

      await expectLater(api.refreshToken(), throwsA(isA<StateError>()));
      expect(await _credential('hutToken'), token);
      expect(await _credential('hutRefreshToken'), 'ref');
      expect(await _credential('hutAccount'), '20260001');
      expect(await _credential('hutMobile'), '13800138000');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
      expect(prefs.getBool('hutIsLogin'), isTrue);
    });
  });

  test('getFunctionList reports authentication required explicitly', () async {
    _seed({
      'hutAuthMethod': kHutAuthMethodSms,
      'hutToken': 'not-a-jwt',
      'hutIsLogin': true,
    });

    await expectLater(
      HutUserApi().getFunctionList(),
      throwsA(isA<HutAuthenticationRequiredException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hutIsLogin'), isFalse);
  });
}
