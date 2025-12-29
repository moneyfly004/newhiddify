import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdHelper {
  static const String _deviceIdKey = 'device_id';
  static const String _deviceNameKey = 'device_name';

  /// 获取或生成设备ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      deviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// 生成设备ID
  static Future<String> _generateDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      // 优先使用Android ID，如果不可用则使用设备信息组合
      final androidId = androidInfo.id;
      if (androidId.isNotEmpty && androidId != '9774d56d682e549c') {
        return androidId;
      }
      // 备用方案：使用设备信息组合
      return '${androidInfo.brand}_${androidInfo.model}_${androidInfo.id}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      // 桌面平台
      return 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 获取设备名称
  static Future<String> getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceName = prefs.getString(_deviceNameKey);

    if (deviceName == null || deviceName.isEmpty) {
      deviceName = await _generateDeviceName();
      await prefs.setString(_deviceNameKey, deviceName);
    }

    return deviceName;
  }

  /// 生成设备名称
  static Future<String> _generateDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.brand} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return '${iosInfo.name} (${iosInfo.model})';
    } else {
      return Platform.operatingSystem;
    }
  }

  /// 清除设备ID（用于退出登录）
  static Future<void> clearDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
    await prefs.remove(_deviceNameKey);
  }
}

