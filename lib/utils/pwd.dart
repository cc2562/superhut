import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;

// 密钥
final String Sw = "qzkj1kjghd=876&*";

// 模拟 U 函数
String U(dynamic data) {
  if (data is Map) {
    List<String> result = [];
    data.forEach((key, value) {
      String processedKey;
      if (key is String && RegExp(r'[^\w$]').hasMatch(key)) {
        processedKey = jsonEncode(key);
      } else {
        processedKey = key.toString();
      }
      result.add('$processedKey: ${U(value)}');
    });
    return "{${result.join(", ")}}";
  } else if (data is List) {
    List<String> result = [];
    for (int i = 0; i < data.length; i++) {
      result.add('$i: ${U(data[i])}');
    }
    return "{${result.join(", ")}}";
  } else if (data is String) {
    return jsonEncode(data);
  } else if (data is num) {
    return data.toString();
  } else if (data is bool) {
    return data ? 'true' : 'false';
  } else if (data == null) {
    return 'null';
  } else {
    return jsonEncode(data);
  }
}

// 加密函数
String encryptPassword(String password, String key) {
  // 处理密钥
  List<int> keyBytes = utf8.encode(key);
  keyBytes = keyBytes.take(16).toList();
  if (keyBytes.length < 16) {
    keyBytes.addAll(List.filled(16 - keyBytes.length, 0));
  }
  final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));

  // 处理密码
  final processedPassword = U(password);

  // 创建加密器
  final aes = encrypt.Encrypter(
    encrypt.AES(encryptKey, mode: encrypt.AESMode.ecb, padding: 'PKCS7'),
  );

  // 加密数据
  final encrypted = aes.encryptBytes(
    utf8.encode(processedPassword),
    iv: encrypt.IV.fromLength(16),
  );

  // 修正这里：添加.bytes获取实际字节
  return base64Encode(encrypted.bytes);
}

// 这里原本有一段带明文示例密码的调试用 main()，已删除：
// 源码里不应该出现任何真实凭据，也不应该打印加密后的密码。
