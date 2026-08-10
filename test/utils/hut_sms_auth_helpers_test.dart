import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  test('buildHutSmsInitPath is under /token/passwordless', () {
    expect(buildHutSmsInitPath(), '/token/passwordless/smsInit');
  });

  test('buildHutSmsSendPath puts mobile and nonce in query', () {
    final path = buildHutSmsSendPath(mobile: '13800138000', nonce: 'abc');
    expect(path.startsWith('/token/passwordless/smsSend?'), isTrue);
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('nonce=abc'));
  });

  test('buildHutSmsLoginPath includes required query keys', () {
    final path = buildHutSmsLoginPath(
      mobile: '13800138000',
      smscode: '123456',
      appId: 'com.supwisdom.hut',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      osType: 'iOS',
      geo: '',
      nonce: 'oUOHnB',
    );
    expect(path, contains('/token/passwordless/smsLogin?'));
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('smscode=123456'));
    expect(path, contains('appId=com.supwisdom.hut'));
    expect(path, contains('deviceId=abcdefghijklmnopqrstuvwx'));
    expect(path, contains('osType=iOS'));
    expect(path, contains('nonce=oUOHnB'));
    expect(path, contains('clientId=CLIENT_ID'));
  });

  test('buildHutSmsLoginPath allows overriding clientId', () {
    final path = buildHutSmsLoginPath(
      mobile: '13800138000',
      smscode: '123456',
      appId: 'com.supwisdom.hut',
      deviceId: 'abc',
      osType: 'iOS',
      geo: '',
      nonce: 'n',
      clientId: 'custom',
    );
    expect(path, contains('clientId=custom'));
  });

  test('parseHutSmsInitResponse reads nonce on code 0', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {'success': true, 'message': 'SMS init success', 'nonce': 'oUOHnB'},
    });
    expect(result.success, isTrue);
    expect(result.nonce, 'oUOHnB');
  });

  test('parseHutSmsInitResponse fails without nonce', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {'success': true, 'message': 'ok'},
    });
    expect(result.success, isFalse);
    expect(result.nonce, isNull);
  });

  test('parseHutSmsSendResponse fails on non-zero code with message', () {
    final result = parseHutSmsSendResponse({
      'code': 1,
      'message': '发送过于频繁',
      'data': null,
    });
    expect(result.success, isFalse);
    expect(result.message, contains('频繁'));
  });

  test('parseHutSmsSendResponse reads top-level error field', () {
    final result = parseHutSmsSendResponse({
      'code': -1,
      'error': '请求不合法',
      'data': null,
    });
    expect(result.success, isFalse);
  });

  test('parseHutSmsLoginTokenData succeeds when idToken present', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'idToken': 'tok', 'refreshToken': 'ref'},
    });
    expect(result.success, isTrue);
  });

  test('parseHutSmsLoginTokenData fails when token missing', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'refreshToken': 'ref'},
    });
    expect(result.success, isFalse);
  });

  test('hutResponseIndicatesNeedMfa detects flag', () {
    expect(
      hutResponseIndicatesNeedMfa({
        'code': 0,
        'data': {'needMfa': true, 'mfaState': 'xyz'},
      }),
      isTrue,
    );
    expect(
      hutResponseIndicatesNeedMfa({'code': 0, 'data': {'idToken': 't'}}),
      isFalse,
    );
  });

  test('isPlausibleHutMobile and normalizeHutMobile', () {
    expect(isPlausibleHutMobile('13800138000'), isTrue);
    expect(isPlausibleHutMobile('138 0013 8000'), isTrue);
    expect(isPlausibleHutMobile('123'), isFalse);
    expect(normalizeHutMobile(' 138 0013 8000 '), '13800138000');
  });

  test('isHutSmsSessionInvalidMessage detects stale nonce', () {
    expect(isHutSmsSessionInvalidMessage('nonce invalid'), isTrue);
    expect(isHutSmsSessionInvalidMessage('验证码已失效，请重新获取'), isTrue);
    expect(isHutSmsSessionInvalidMessage('手机号错误'), isFalse);
  });
}