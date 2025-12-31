import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限服务
class PermissionService {
  static const MethodChannel _channel = MethodChannel('com.proxyapp/permissions');

  /// 请求 VPN 权限
  static Future<bool> requestVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('VPN权限请求失败: ${e.message}');
      return false;
    }
  }

  /// 检查 VPN 权限
  static Future<bool> checkVpnPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkVpnPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 请求通知权限
  static Future<bool> requestNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      return true;
    }
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 请求忽略电池优化
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// 检查忽略电池优化
  static Future<bool> checkIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// 请求所有必要权限
  static Future<Map<String, bool>> requestAllPermissions() async {
    return {
      'vpn': await requestVpnPermission(),
      'notification': await requestNotificationPermission(),
      'batteryOptimization': await requestIgnoreBatteryOptimizations(),
    };
  }
}

