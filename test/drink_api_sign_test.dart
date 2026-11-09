import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/oct_signature.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('oct 签名还原', () {
    test('decDoubleLayer 解出静态密钥段 59733379783d6a37', () {
      expect(_hex(octSecret8()), '59733379783d6a37');
    });

    test('样本 A：authCode=123456 命中 509d82d6…', () {
      final result = octComputeSignature(
        params: const {'authCode': '123456', 'un': '18687172208'},
        path: '/api/v1/acc/login',
        epochSeconds: 1794160080,
      );

      expect(result.strF, 'authCode=123456&un=18687172208');
      expect(result.strB, '86871722');
      expect(result.strC, 'acclogin');
      expect(result.strD, '94160080');
      expect(result.sign, '509d82d6927db86149420e61cdac6d85');
    });

    test('样本 B：authCode=021023 命中 e978ed7d…', () {
      final result = octComputeSignature(
        params: const {'authCode': '021023', 'un': '18687172208'},
        path: '/api/v1/acc/login',
        epochSeconds: 1794134400,
      );

      expect(result.strD, '94134400');
      expect(result.sign, 'e978ed7d43c22cc3339a25d3aaf364ad');
    });

    test('时间按 30 秒对齐，对齐前后签名一致', () {
      final aligned = octComputeSignature(
        params: const {'authCode': '021023', 'un': '18687172208'},
        path: '/api/v1/acc/login',
        epochSeconds: 1794134400,
      );
      final within = octComputeSignature(
        params: const {'authCode': '021023', 'un': '18687172208'},
        path: '/api/v1/acc/login',
        epochSeconds: 1794134429,
      );

      expect(within.alignedEpoch, aligned.alignedEpoch);
      expect(within.sign, aligned.sign);
    });

    test('token 非空时 strB 取自 token', () {
      final result = octComputeSignature(
        params: const {'authCode': '021023', 'un': '18687172208'},
        path: '/api/v1/acc/login',
        token: 'abcdefghijklmnop',
        epochSeconds: 1794134400,
      );

      // 16 位 token → 起点 (16-8)/2 = 4 → 'efghijkl'
      expect(result.strB, 'efghijkl');
    });
  });

  group('blake3 keyed', () {
    final sampleKey = <int>[
      ..._hexToBytes('59733379783d6a37'),
      ...utf8.encode('94160080'),
      ...utf8.encode('86871722'),
      ...utf8.encode('acclogin'),
    ];

    test('单 chunk（32 字节输入）与参考实现一致', () {
      expect(
        _hex(blake3Keyed(sampleKey, utf8.encode('authCode=123456&un=18687172208'))),
        '509d82d6927db86149420e61cdac6d85b05ae07ef3dd923d92ac22ce03728850',
      );
    });

    test('空输入与参考实现一致', () {
      expect(
        _hex(blake3Keyed(sampleKey, const [])),
        '116fc0b25b2b948a69ab381629eeaf47efef11e2a6eb62766a52e5ea6f24cdee',
      );
    });

    test('多 chunk（2000 字节）树形合并与参考实现一致', () {
      expect(
        _hex(blake3Keyed(sampleKey, utf8.encode('x' * 2000))),
        '6d5043b9573d4488dc611f3a6357b7e1a9da0578e24852b16e9c07c5d98eb50c',
      );
    });

    test('key 长度非 32 字节时直接报错，不静默降级', () {
      expect(
        () => blake3Keyed(const [1, 2, 3], utf8.encode('a')),
        throwsArgumentError,
      );
    });
  });

  group('OctUtil 辅助映射', () {
    test('middle8 取居中 8 位', () {
      expect(octMiddle8('18687172208'), '86871722');
      expect(octMiddle8('1234'), '1234');
    });

    test('path8 去符号取后 8 位', () {
      expect(octPath8('/api/v1/acc/login'), 'acclogin');
    });

    test('time8 取 30 秒对齐后 8 位', () {
      expect(octTime8(1794160084), '94160080');
      expect(octTime8(1794134400), '94134400');
    });

    test('paramString 按 key 字典序拼接', () {
      expect(
        octParamString(const {'un': '18687172208', 'authCode': '021023'}),
        'authCode=021023&un=18687172208',
      );
    });
  });

  group('drinkLoginBody', () {
    test('只带 authCode 与 un，不再携带 cid / openCode', () {
      final body = drinkLoginBody(phone: '13800138000', code: '123456');

      expect(body.keys.toSet(), {'authCode', 'un'});
      expect(body['authCode'], '123456');
      expect(body['un'], '13800138000');
    });
  });
}

List<int> _hexToBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}
