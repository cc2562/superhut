import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/hut_user_api.dart';

String _buildJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const signature = 'sig';
  return '$header.$body.$signature';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('_completeSmsLoginFromResponseData clears old password creds', () {
    test(
      'removes hutUsername/hutPassword and marks hutAuthMethod=sms',
      () async {
        // Simulate a prior password login.
        SharedPreferences.setMockInitialValues({
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
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutToken'), rawIdToken);
        expect(prefs.getString('hutRefreshToken'), 'new-ref');
        expect(prefs.getString('hutAccount'), '20260001');
        expect(prefs.getString('deviceId'), 'dev-1');
        expect(prefs.getString('hutMobile'), '13800138000');
        expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
        expect(prefs.getString('hutUsername'), isNull);
        expect(prefs.getString('hutPassword'), isNull);
        expect(prefs.getBool('hutIsLogin'), isTrue);
      },
    );
  });

  group('checkTokenValidity SMS branch', () {
    test('returns false when token is empty', () async {
      SharedPreferences.setMockInitialValues({
        'hutAuthMethod': kHutAuthMethodSms,
      });
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test('returns false for an expired JWT', () async {
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      SharedPreferences.setMockInitialValues({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': _buildJwt({'exp': pastExp}),
      });
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test('returns false for a corrupted/non-JWT token', () async {
      SharedPreferences.setMockInitialValues({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': 'not-a-jwt',
      });
      expect(await HutUserApi().checkTokenValidity(), isFalse);
    });

    test(
      'returns server verdict for a fresh SMS token using hutAccount',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        SharedPreferences.setMockInitialValues({
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

    test(
      'migrates a legacy SMS session by extracting sub before validation',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': 'legacy-account', 'exp': futureExp});
        SharedPreferences.setMockInitialValues({
          'hutToken': token,
          'deviceId': 'legacy-device',
        });

        final api = HutUserApi(
          onlineTokenValidator: ({
            required token,
            required account,
            required deviceId,
          }) async {
            expect(account, 'legacy-account');
            return true;
          },
        );

        expect(await api.checkTokenValidity(), isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutAccount'), 'legacy-account');
      },
    );
  });

  group('refreshToken SMS degrades safely', () {
    test('clears login state but keeps hutMobile when token invalid', () async {
      SharedPreferences.setMockInitialValues({
        'hutAuthMethod': kHutAuthMethodSms,
        'hutToken': 'not-a-jwt',
        'hutRefreshToken': 'ref',
        'hutAccount': '20260001',
        'hutMobile': '13800138000',
        'hutIsLogin': true,
      });

      final ok = await HutUserApi().refreshToken();
      expect(ok, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hutToken'), isNull);
      expect(prefs.getString('hutRefreshToken'), isNull);
      expect(prefs.getString('hutAccount'), isNull);
      expect(prefs.getString('hutAuthMethod'), isNull);
      expect(prefs.getBool('hutIsLogin'), isFalse);
      // Mobile preserved so the user can re-request a code without retyping.
      expect(prefs.getString('hutMobile'), '13800138000');
    });

    test(
      'clears SMS auth state when the server rejects a fresh token',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        SharedPreferences.setMockInitialValues({
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
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutToken'), isNull);
        expect(prefs.getString('hutRefreshToken'), isNull);
        expect(prefs.getString('hutAccount'), isNull);
        expect(prefs.getString('hutAuthMethod'), isNull);
        expect(prefs.getBool('hutIsLogin'), isFalse);
        expect(prefs.getString('hutMobile'), '13800138000');
      },
    );

    test(
      'keeps SMS auth state when the server accepts a fresh token',
      () async {
        final futureExp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
        final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
        SharedPreferences.setMockInitialValues({
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
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('hutToken'), token);
        expect(prefs.getString('hutRefreshToken'), 'ref');
        expect(prefs.getString('hutAccount'), '20260001');
        expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
        expect(prefs.getBool('hutIsLogin'), isTrue);
        expect(prefs.getString('hutMobile'), '13800138000');
      },
    );

    test('preserves SMS auth state when online validation throws', () async {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
      SharedPreferences.setMockInitialValues({
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
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('hutToken'), token);
      expect(prefs.getString('hutRefreshToken'), 'ref');
      expect(prefs.getString('hutAccount'), '20260001');
      expect(prefs.getString('hutAuthMethod'), kHutAuthMethodSms);
      expect(prefs.getBool('hutIsLogin'), isTrue);
      expect(prefs.getString('hutMobile'), '13800138000');
    });
  });

  test('getFunctionList reports authentication required explicitly', () async {
    SharedPreferences.setMockInitialValues({
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
