import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 应用信息服务 - 获取已安装应用列表
class AppInfoService {
  static const MethodChannel _channel = MethodChannel('com.proxyapp/app_info');
  
  /// 获取已安装应用列表
  static Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
      if (result == null) return [];
      
      return result.map((app) {
        final map = app as Map<dynamic, dynamic>;
        return InstalledApp(
          name: map['name'] as String? ?? '',
          packageName: map['packageName'] as String? ?? '',
          iconPath: map['iconPath'] as String?,
        );
      }).toList();
    } on PlatformException catch (e) {
      throw Exception('获取应用列表失败: ${e.message}');
    }
  }
  
  /// 获取应用图标
  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException {
      return null;
    }
  }
}

/// 已安装应用信息
class InstalledApp {
  final String name;
  final String packageName;
  final String? iconPath;

  InstalledApp({
    required this.name,
    required this.packageName,
    this.iconPath,
  });
}

