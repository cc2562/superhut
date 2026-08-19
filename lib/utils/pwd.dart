import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;

const String academicPasswordKey = "qzkj1kjghd=876&*";

String U(dynamic data) {
  if (data is Map) {
    final result = <String>[];
    data.forEach((key, value) {
      final String processedKey;
      if (key is String && RegExp(r'[^\w$]').hasMatch(key)) {
        processedKey = jsonEncode(key);
      } else {
        processedKey = key.toString();
      }
      result.add('$processedKey: ${U(value)}');
    });
    return "{${result.join(", ")}}";
  }
  if (data is List) {
    final result = <String>[];
    for (var index = 0; index < data.length; index += 1) {
      result.add('$index: ${U(data[index])}');
    }
    return "{${result.join(", ")}}";
  }
  if (data is String) return jsonEncode(data);
  if (data is num) return data.toString();
  if (data is bool) return data ? 'true' : 'false';
  if (data == null) return 'null';
  return jsonEncode(data);
}

String encryptPassword(String password, String key) {
  var keyBytes = utf8.encode(key).take(16).toList();
  if (keyBytes.length < 16) {
    keyBytes.addAll(List.filled(16 - keyBytes.length, 0));
  }
  final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));
  final aes = encrypt.Encrypter(
    encrypt.AES(encryptKey, mode: encrypt.AESMode.ecb, padding: 'PKCS7'),
  );
  final encrypted = aes.encryptBytes(
    utf8.encode(U(password)),
    iv: encrypt.IV.fromLength(16),
  );
  return base64Encode(encrypted.bytes);
}
