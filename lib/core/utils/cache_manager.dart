import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 缓存管理器
class CacheManager {
  static const String _cachePrefix = 'cache_';
  static const String _cacheTimestampPrefix = 'cache_timestamp_';
  static const Duration _defaultExpiry = Duration(hours: 1);

  /// 保存缓存
  static Future<void> setCache(
    String key,
    dynamic value, {
    Duration? expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDuration = expiry ?? _defaultExpiry;
    final expiryTime = DateTime.now().add(expiryDuration);

    await prefs.setString(
      '$_cachePrefix$key',
      jsonEncode(value),
    );
    await prefs.setString(
      '$_cacheTimestampPrefix$key',
      expiryTime.toIso8601String(),
    );
  }

  /// 获取缓存
  static Future<T?> getCache<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 检查是否过期
    final timestampStr = prefs.getString('$_cacheTimestampPrefix$key');
    if (timestampStr != null) {
      final expiryTime = DateTime.parse(timestampStr);
      if (DateTime.now().isAfter(expiryTime)) {
        // 缓存已过期，删除
        await prefs.remove('$_cachePrefix$key');
        await prefs.remove('$_cacheTimestampPrefix$key');
        return null;
      }
    }

    final cacheStr = prefs.getString('$_cachePrefix$key');
    if (cacheStr == null) return null;

    try {
      return jsonDecode(cacheStr) as T;
    } catch (e) {
      return null;
    }
  }

  /// 清除缓存
  static Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$key');
    await prefs.remove('$_cacheTimestampPrefix$key');
  }

  /// 清除所有缓存
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_cachePrefix) || key.startsWith(_cacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}

