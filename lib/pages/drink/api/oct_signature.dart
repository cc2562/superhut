/// 慧生活798（com.cloudora.android）acc/login 的签名实现。
///
/// 算法来自官方 3.1.10 的 `liboct.so`，与 `OctUtil.d()` 的 Java 侧拼接逻辑完全对齐：
///
/// ```
/// strF  = 参数按 key 字典序拼成 "k1=v1&k2=v2"（跳过空值）
/// strB  = token 非空时取 token 的中间 8 位，否则取手机号的中间 8 位
/// strC  = 请求路径去掉非字母数字后取后 8 位
/// strD  = 服务端时间（30 秒对齐的 epoch 秒）十进制串的后 8 位
/// key32 = secret8(8B) + strD(8B) + strB(8B) + strC(8B)   // 共 32 字节
/// sign  = hex(blake3_keyed(key32, strF))[0:32]
/// ```
///
/// `secret8` 由 `decDoubleLayer("BA17B4BE25C1B433BCBD7C1E9582072E")` 得到，
/// 即「hex 解码 → AES-128-ECB 解密 → 去 PKCS#7 填充 → 再走一遍流变换」，
/// 解出来的固定值是 `59733379783d6a37`（见 [octSecret8]）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

/// 参与 `decDoubleLayer` 的静态串（liboct.so `0xa1eea`）。
const String _staticHex = 'BA17B4BE25C1B433BCBD7C1E9582072E';

/// 用***AES 密钥的静态串（liboct.so `0x...`，与 `_staticHex` 同一段解密流程）。
const String _aesKeyHex = '9250651F9EC193106E6185429961A50B';

/// 流变换里的固定表（liboct.so `0x3fbd0` / `0x3fd9c`）。
const List<int> _streamTable = [
  0xe4, 0x36, 0x2c, 0x24, 0x9e, 0x96, 0x7b, 0x62,
  0xd9, 0x6e, 0x2c, 0x9c, 0x4e, 0x49, 0x80, 0x3e,
];

/// `secret8` 的十六进制形式，与 [octSecret8] 的推导结果一致。
const String octSecretHex = '59733379783d6a37';

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _bytesToHex(List<int> bytes) {
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

/// liboct.so 里的字节流交换（`0x3fbd0` 与 `0x3fd9c` 是同一段实现）。
Uint8List _streamXor(List<int> data) {
  final out = Uint8List(data.length);
  var w9 = 0;
  var w11 = 0x5a;
  for (var i = 0; i < data.length; i++) {
    final x = data[i] & 0xFF;
    final k = w9 ^ w11;
    w9 = (w9 + 0x9d) & 0xFFFFFFFF;
    out[i] = (_streamTable[i & 0xf] ^ x ^ k) & 0xFF;
    w11 = (x * 0x33 + (w11 & 0xFF) + 0x11) & 0xFFFFFFFF;
  }
  return out;
}

Uint8List? _secretCache;

/// 还原 `decDoubleLayer` 的结果：8 字节静态密钥段。
///
/// 结果恒为 `59733379783d6a37`；这里保留完整推导而不是写死常量，
/// 是为了让「静态串 → 流变换 → AES → 去填充」这条链在代码里可验证。
Uint8List octSecret8() {
  final cached = _secretCache;
  if (cached != null) return cached;

  final aesKey = _streamXor(_hexToBytes(_aesKeyHex));
  final encrypter = enc.Encrypter(
    enc.AES(enc.Key(aesKey), mode: enc.AESMode.ecb, padding: null),
  );
  final plain = encrypter.decryptBytes(enc.Encrypted(_hexToBytes(_staticHex)));
  final pad = plain.isEmpty ? 0 : plain.last;
  if (pad < 1 || pad > 16) {
    throw StateError('decDoubleLayer 填充非法: $pad');
  }
  final secret = Uint8List.fromList(_streamXor(plain.sublist(0, 16 - pad)));
  _secretCache = secret;
  return secret;
}

/// `OctUtil.b()`：长度 ≥ 8 时取居中的 8 个字符，否则原样返回。
String octMiddle8(String text) {
  if (text.length >= 8) {
    return text.substring((text.length - 8) ~/ 2, (text.length - 8) ~/ 2 + 8);
  }
  return text;
}

/// `OctUtil.c()`：去掉非字母数字后取后 8 位（`/api/v1/acc/login` → `acclogin`）。
String octPath8(String path) {
  final alnum = path.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  return alnum.length > 8 ? alnum.substring(alnum.length - 8) : alnum;
}

/// `OctUtil.a()`：30 秒对齐的 epoch 秒，取十进制串的后 8 位。
String octTime8(int epochSeconds) {
  final aligned = (epochSeconds ~/ 30) * 30;
  final text = aligned.toString();
  return text.length > 8 ? text.substring(text.length - 8) : text;
}

/// `OctUtil.f()`：按 key 字典序拼 `k=v`，用 `&` 连接。
String octParamString(Map<String, String> params) {
  final keys = params.keys.where((k) => params[k]!.isNotEmpty).toList()..sort();
  return keys.map((k) => '$k=${params[k]}').join('&');
}

/// 一次签名的全部中间量与结果，供日志诊断与测试断言使用。
class OctSignature {
  const OctSignature({
    required this.path,
    required this.epoch,
    required this.alignedEpoch,
    required this.secretHex,
    required this.strF,
    required this.strB,
    required this.strC,
    required this.strD,
    required this.keyHex,
    required this.sign,
  });

  final String path;

  /// 参与计算的时间（已含服务端时钟偏移）。
  final int epoch;

  /// 30 秒对齐后的时间。
  final int alignedEpoch;

  final String secretHex;
  final String strF;
  final String strB;
  final String strC;
  final String strD;
  final String keyHex;
  final String sign;

  /// 供 `debugPrint` 直接输出的多行诊断。
  String describe() {
    return 'secret8 = $secretHex\n'
        'strF    = $strF\n'
        'strB    = $strB\n'
        'strC    = $strC\n'
        'strD    = $strD\n'
        'key32   = $keyHex\n'
        'sign    = $sign';
  }
}

/// 计算 `acc/login` 的 `sign`。
///
/// [epochSeconds] 必须是**服务端时间**（30 秒对齐在内部完成）。
/// [token] 为空表示未登录（`strB` 退回取手机号中间 8 位）。
OctSignature octComputeSignature({
  required Map<String, String> params,
  required String path,
  required int epochSeconds,
  String token = '',
}) {
  final secret = octSecret8();
  final strF = octParamString(params);
  final strB = token.isNotEmpty ? octMiddle8(token) : octMiddle8(params['un'] ?? '');
  final strC = octPath8(path);
  final alignedEpoch = (epochSeconds ~/ 30) * 30;
  final strD = octTime8(epochSeconds);

  final key = Uint8List(secret.length + strD.length + strB.length + strC.length);
  var offset = 0;
  for (final part in [secret, utf8.encode(strD), utf8.encode(strB), utf8.encode(strC)]) {
    key.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  if (key.length != 32) {
    throw StateError('blake3 keyed 需要 32 字节 key，实际 ${key.length}');
  }

  final digest = blake3Keyed(key, utf8.encode(strF), outLen: 32);
  final sign = _bytesToHex(digest).substring(0, 32);

  return OctSignature(
    path: path,
    epoch: epochSeconds,
    alignedEpoch: alignedEpoch,
    secretHex: _bytesToHex(secret),
    strF: strF,
    strB: strB,
    strC: strC,
    strD: strD,
    keyHex: _bytesToHex(key),
    sign: sign,
  );
}

// ---------------------------------------------------------------------------
// BLAKE3（keyed 模式），纯 Dart 实现，无平台通道。
// 只用到 32 字节输出，但内部按完整规范处理多 chunk 的树形合并。
// ---------------------------------------------------------------------------

const List<int> _iv = [
  0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
  0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
];

const List<int> _msgPermutation = [
  2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8,
];

const int _flagChunkStart = 1 << 0;
const int _flagChunkEnd = 1 << 1;
const int _flagParent = 1 << 2;
const int _flagRoot = 1 << 3;
const int _flagKeyedHash = 1 << 4;

const int _blockLen = 64;
const int _chunkLen = 1024;

int _rotr(int value, int count) =>
    ((value >> count) | (value << (32 - count))) & 0xFFFFFFFF;

void _mix(List<int> s, int a, int b, int c, int d, int mx, int my) {
  s[a] = (s[a] + s[b] + mx) & 0xFFFFFFFF;
  s[d] = _rotr(s[d] ^ s[a], 16);
  s[c] = (s[c] + s[d]) & 0xFFFFFFFF;
  s[b] = _rotr(s[b] ^ s[c], 12);
  s[a] = (s[a] + s[b] + my) & 0xFFFFFFFF;
  s[d] = _rotr(s[d] ^ s[a], 8);
  s[c] = (s[c] + s[d]) & 0xFFFFFFFF;
  s[b] = _rotr(s[b] ^ s[c], 7);
}

void _round(List<int> s, List<int> m) {
  _mix(s, 0, 4, 8, 12, m[0], m[1]);
  _mix(s, 1, 5, 9, 13, m[2], m[3]);
  _mix(s, 2, 6, 10, 14, m[4], m[5]);
  _mix(s, 3, 7, 11, 15, m[6], m[7]);
  _mix(s, 0, 5, 10, 15, m[8], m[9]);
  _mix(s, 1, 6, 11, 12, m[10], m[11]);
  _mix(s, 2, 7, 8, 13, m[12], m[13]);
  _mix(s, 3, 4, 9, 14, m[14], m[15]);
}

List<int> _compress(
  List<int> cv,
  List<int> blockWords,
  int counter,
  int blockLength,
  int flags,
) {
  final state = List<int>.filled(16, 0);
  for (var i = 0; i < 8; i++) {
    state[i] = cv[i];
  }
  for (var i = 0; i < 4; i++) {
    state[8 + i] = _iv[i];
  }
  state[12] = counter & 0xFFFFFFFF;
  state[13] = (counter >> 32) & 0xFFFFFFFF;
  state[14] = blockLength;
  state[15] = flags;

  var m = List<int>.from(blockWords);
  for (var r = 0; r < 7; r++) {
    _round(state, m);
    if (r < 6) {
      m = [for (final i in _msgPermutation) m[i]];
    }
  }

  final out = List<int>.filled(16, 0);
  for (var i = 0; i < 8; i++) {
    out[i] = state[i] ^ state[i + 8];
    out[i + 8] = state[i + 8] ^ cv[i];
  }
  return out;
}

/// 把 [length] 字节按小端拼成 16 个 32 位字（不足补 0）。
List<int> _blockWords(List<int> source, int start, int length) {
  final words = List<int>.filled(16, 0);
  final full = length >> 2;
  for (var i = 0; i < full; i++) {
    final p = start + i * 4;
    words[i] = (source[p] |
            (source[p + 1] << 8) |
            (source[p + 2] << 16) |
            (source[p + 3] << 24)) &
        0xFFFFFFFF;
  }
  for (var i = full * 4; i < length; i++) {
    words[i >> 2] |= (source[start + i] & 0xFF) << (8 * (i & 3));
  }
  return words;
}

/// 一个尚未被压成 chaining value 的压缩输入。
class _Blake3Output {
  const _Blake3Output(
    this.cv,
    this.blockWords,
    this.counter,
    this.blockLength,
    this.flags,
  );

  final List<int> cv;
  final List<int> blockWords;
  final int counter;
  final int blockLength;
  final int flags;

  List<int> chainingValue() =>
      _compress(cv, blockWords, counter, blockLength, flags).sublist(0, 8);

  Uint8List rootBytes(int outLength) {
    final out = Uint8List(outLength);
    var blockCounter = 0;
    var offset = 0;
    while (offset < outLength) {
      final words = _compress(
        cv,
        blockWords,
        blockCounter,
        blockLength,
        flags | _flagRoot,
      );
      for (var i = 0; i < 16 && offset < outLength; i++) {
        final w = words[i];
        for (var b = 0; b < 4 && offset < outLength; b++) {
          out[offset++] = (w >> (8 * b)) & 0xFF;
        }
      }
      blockCounter++;
    }
    return out;
  }
}

_Blake3Output _chunkOutput(
  List<int> keyWords,
  List<int> chunk,
  int chunkCounter,
  int baseFlags,
) {
  final blockCount = chunk.isEmpty ? 1 : ((chunk.length + _blockLen - 1) >> 6);
  var cv = keyWords;
  for (var i = 0; i < blockCount; i++) {
    final start = i * _blockLen;
    final end = start + _blockLen > chunk.length ? chunk.length : start + _blockLen;
    final length = end - start;
    var flags = baseFlags;
    if (i == 0) flags |= _flagChunkStart;
    if (i == blockCount - 1) flags |= _flagChunkEnd;
    final output = _Blake3Output(
      cv,
      _blockWords(chunk, start, length),
      chunkCounter,
      length,
      flags,
    );
    if (i == blockCount - 1) return output;
    cv = output.chainingValue();
  }
  throw StateError('unreachable');
}

_Blake3Output _parentOutput(
  List<int> keyWords,
  List<int> left,
  List<int> right,
  int baseFlags,
) {
  final block = List<int>.filled(16, 0);
  for (var i = 0; i < 8; i++) {
    block[i] = left[i];
    block[8 + i] = right[i];
  }
  return _Blake3Output(
    keyWords,
    block,
    0,
    _blockLen,
    baseFlags | _flagParent,
  );
}

/// BLAKE3 keyed hash。[key] 必须是 32 字节。
Uint8List blake3Keyed(
  List<int> key,
  List<int> input, {
  int outLen = 32,
}) {
  if (key.length != 32) {
    throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
  }
  final keyWords = _blockWords(key, 0, 32);
  final baseFlags = _flagKeyedHash;
  final cvStack = <List<int>>[];

  var counter = 0;
  var pos = 0;
  while (input.length - pos > _chunkLen) {
    final chunk = input.sublist(pos, pos + _chunkLen);
    var cv = _chunkOutput(keyWords, chunk, counter, baseFlags).chainingValue();
    counter++;
    var total = counter;
    while (total & 1 == 0) {
      cv = _parentOutput(keyWords, cvStack.removeLast(), cv, baseFlags)
          .chainingValue();
      total >>= 1;
    }
    cvStack.add(cv);
    pos += _chunkLen;
  }

  var output = _chunkOutput(keyWords, input.sublist(pos), counter, baseFlags);
  while (cvStack.isNotEmpty) {
    output = _parentOutput(
      keyWords,
      cvStack.removeLast(),
      output.chainingValue(),
      baseFlags,
    );
  }
  return output.rootBytes(outLen);
}
