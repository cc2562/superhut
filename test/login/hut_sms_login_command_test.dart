import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  test('requestCode success starts countdown and stores nonce', () async {
    late final HutSmsLoginCommand command;
    command = HutSmsLoginCommand(
      countdownSeconds: 60,
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend: ({required mobile, required nonce}) async {
        expect(mobile, '13800138000');
        expect(nonce, 'n1');
        // Nonce must not be committed before send succeeds.
        expect(command.activeNonce, isNull);
        return const HutAuthResult(success: true, message: 'ok');
      },
    );

    final result = await command.requestCode('13800138000');
    expect(result.success, isTrue);
    expect(command.remainingSeconds, 60);
    expect(command.activeNonce, 'n1');
    expect(command.boundMobile, '13800138000');

    command.debugElapseSecond();
    expect(command.remainingSeconds, 59);

    command.dispose();
  });

  test('requestCode prefers nonce returned by smsSend', () async {
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'init-n'),
      smsSend:
          ({required mobile, required nonce}) async =>
              const HutAuthResult(success: true, nonce: 'send-n'),
    );
    final result = await command.requestCode('13800138000');
    expect(result.success, isTrue);
    expect(command.activeNonce, 'send-n');
    command.dispose();
  });

  test('requestCode does not start countdown on send failure', () async {
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend:
          ({required mobile, required nonce}) async =>
              const HutAuthResult(success: false, message: '发送过于频繁'),
    );
    final result = await command.requestCode('13800138000');
    expect(result.success, isFalse);
    expect(command.remainingSeconds, 0);
    expect(command.activeNonce, isNull);
    expect(command.boundMobile, isNull);
  });

  test(
    'login rejects mobile different from the one that received the code',
    () async {
      var loginCalls = 0;
      final command = HutSmsLoginCommand(
        smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
        smsSend:
            ({required mobile, required nonce}) async =>
                const HutAuthResult(success: true),
        smsLogin: ({required mobile, required smscode, required nonce}) async {
          loginCalls++;
          return const HutAuthResult(success: true);
        },
      );
      await command.requestCode('13800138000');
      final result = await command.login(
        mobile: '13900139000',
        smscode: '123456',
      );
      expect(result.success, isFalse);
      expect(result.message, contains('手机号'));
      expect(loginCalls, 0);
      command.dispose();
    },
  );

  test('login clears nonce after Bad request style failure', () async {
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend:
          ({required mobile, required nonce}) async =>
              const HutAuthResult(success: true),
      smsLogin:
          ({required mobile, required smscode, required nonce}) async =>
              const HutAuthResult(success: false, message: 'Bad request'),
    );
    await command.requestCode('13800138000');
    final result = await command.login(
      mobile: '13800138000',
      smscode: '123456',
    );
    expect(result.success, isFalse);
    expect(result.message, contains('重新获取'));
    expect(command.activeNonce, isNull);
    command.dispose();
  });

  test('requestCode rejects invalid mobile without calling network', () async {
    var initCalls = 0;
    final command = HutSmsLoginCommand(
      smsInit: () async {
        initCalls++;
        return const HutAuthResult(success: true, nonce: 'n');
      },
    );
    final result = await command.requestCode('123');
    expect(result.success, isFalse);
    expect(initCalls, 0);
  });

  test('login reuses in-flight future', () async {
    final completer = Completer<HutAuthResult>();
    var loginCalls = 0;
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend:
          ({required mobile, required nonce}) async =>
              const HutAuthResult(success: true),
      smsLogin: ({required mobile, required smscode, required nonce}) {
        loginCalls++;
        return completer.future;
      },
    );
    await command.requestCode('13800138000');

    final first = command.login(mobile: '13800138000', smscode: '123456');
    final second = command.login(mobile: '13800138000', smscode: '123456');
    expect(identical(first, second), isTrue);
    expect(loginCalls, 1);

    completer.complete(const HutAuthResult(success: true, message: '登录成功'));
    await Future.wait([first, second]);
    expect(loginCalls, 1);
    command.dispose();
  });

  test('login without nonce fails', () async {
    var loginCalls = 0;
    final command = HutSmsLoginCommand(
      smsLogin: ({required mobile, required smscode, required nonce}) async {
        loginCalls++;
        return const HutAuthResult(success: true);
      },
    );
    final result = await command.login(mobile: '13800138000', smscode: '1');
    expect(result.success, isFalse);
    expect(loginCalls, 0);
    command.dispose();
  });

  test('countdown elapses via debugElapseSecond', () async {
    final command = HutSmsLoginCommand(
      countdownSeconds: 3,
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend:
          ({required mobile, required nonce}) async =>
              const HutAuthResult(success: true),
    );
    await command.requestCode('13800138000');
    expect(command.remainingSeconds, 3);
    command.debugElapseSecond();
    expect(command.remainingSeconds, 2);
    command.debugElapseSecond();
    command.debugElapseSecond();
    expect(command.remainingSeconds, 0);
    command.dispose();
  });

  test(
    'dispose during in-flight requestCode does not restart countdown',
    () async {
      final sendCompleter = Completer<HutAuthResult>();
      var countdownCallbacks = 0;
      final command = HutSmsLoginCommand(
        countdownSeconds: 60,
        smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
        smsSend: ({required mobile, required nonce}) => sendCompleter.future,
      );
      command.onCountdownChanged = () {
        countdownCallbacks++;
      };

      final request = command.requestCode('13800138000');
      command.dispose();
      expect(command.remainingSeconds, 0);

      sendCompleter.complete(const HutAuthResult(success: true, message: 'ok'));
      final result = await request;

      expect(result.success, isTrue);
      expect(command.remainingSeconds, 0);
      expect(countdownCallbacks, 0);
    },
  );
}