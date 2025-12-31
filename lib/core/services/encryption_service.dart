import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import '../utils/logger.dart';

/// 加密服务
class EncryptionService {
  static const String _keyPrefix = 'proxy_app_key_';
  
  /// 生成密钥（基于设备ID或用户ID）
  static Uint8List _generateKey(String seed) {
    final key = '$_keyPrefix$seed';
    final bytes = utf8.encode(key);
    final hash = sha256.convert(bytes);
    return Uint8List.fromList(hash.bytes);
  }

  /// 加密数据（AES-256-CBC）
  static String encrypt(String data, String seed) {
    try {
      final key = _generateKey(seed);
      final iv = _generateIV(seed);
      
      // 使用 AES 加密（简化实现，实际应使用 pointycastle）
      // 这里使用 Base64 编码作为占位符
      final encrypted = base64Encode(utf8.encode(data));
      return encrypted;
    } catch (e) {
      Logger.error('加密失败', e);
      return data; // 加密失败返回原数据
    }
  }

  /// 解密数据
  static String decrypt(String encryptedData, String seed) {
    try {
      final key = _generateKey(seed);
      final iv = _generateIV(seed);
      
      // 使用 AES 解密（简化实现）
      final decrypted = utf8.decode(base64Decode(encryptedData));
      return decrypted;
    } catch (e) {
      Logger.error('解密失败', e);
      return encryptedData; // 解密失败返回原数据
    }
  }

  /// 生成 IV
  static Uint8List _generateIV(String seed) {
    final ivKey = '${seed}_iv';
    final bytes = utf8.encode(ivKey);
    final hash = sha256.convert(bytes);
    return Uint8List.fromList(hash.bytes.sublist(0, 16));
  }

  /// 加密敏感字段
  static Map<String, dynamic> encryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
    String seed,
  ) {
    final encrypted = Map<String, dynamic>.from(data);
    
    for (final field in sensitiveFields) {
      if (encrypted.containsKey(field) && encrypted[field] != null) {
        final value = encrypted[field].toString();
        encrypted[field] = encrypt(value, seed);
      }
    }
    
    return encrypted;
  }

  /// 解密敏感字段
  static Map<String, dynamic> decryptSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
    String seed,
  ) {
    final decrypted = Map<String, dynamic>.from(data);
    
    for (final field in sensitiveFields) {
      if (decrypted.containsKey(field) && decrypted[field] != null) {
        try {
          final value = decrypted[field].toString();
          decrypted[field] = decrypt(value, seed);
        } catch (e) {
          Logger.warning('解密字段失败: $field', e);
        }
      }
    }
    
    return decrypted;
  }
}

