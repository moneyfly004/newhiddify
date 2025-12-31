import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络工具类
class NetworkUtils {
  static final Connectivity _connectivity = Connectivity();

  /// 检查网络连接
  static Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// 获取网络类型
  static Future<ConnectivityResult> getNetworkType() async {
    final result = await _connectivity.checkConnectivity();
    return result.first;
  }

  /// 监听网络状态变化
  static Stream<List<ConnectivityResult>> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }

  /// 检查是否是 WiFi
  static Future<bool> isWifi() async {
    final result = await getNetworkType();
    return result == ConnectivityResult.wifi;
  }

  /// 检查是否是移动网络
  static Future<bool> isMobile() async {
    final result = await getNetworkType();
    return result == ConnectivityResult.mobile;
  }
}

