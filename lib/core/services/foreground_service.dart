import 'package:flutter/services.dart';

/// 前台服务管理器
class ForegroundService {
  static const MethodChannel _channel =
      MethodChannel('com.proxyapp/foreground_service');

  /// 启动前台服务
  static Future<bool> startService({
    required String title,
    required String content,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startService', {
        'title': title,
        'content': content,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('启动前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 停止前台服务
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('停止前台服务失败: ${e.message}');
      return false;
    }
  }

  /// 更新通知内容
  static Future<bool> updateNotification({
    required String title,
    required String content,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('updateNotification', {
        'title': title,
        'content': content,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      return false;
    }
  }
}

