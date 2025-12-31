import 'dart:async';
import '../utils/logger.dart';
import '../utils/network_utils.dart';
import 'connection_manager.dart';
import 'storage_service.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';

/// 自动重连服务
class AutoReconnectService {
  final ConnectionManager _connectionManager;
  final StorageService _storage;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 10);

  AutoReconnectService(this._connectionManager, this._storage);

  /// 启用自动重连
  void enableAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectInterval, (timer) {
      _checkAndReconnect();
    });
    Logger.info('自动重连已启用');
  }

  /// 禁用自动重连
  void disableAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    Logger.info('自动重连已禁用');
  }

  /// 检查并重连
  Future<void> _checkAndReconnect() async {
    if (_isReconnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      disableAutoReconnect();
      Logger.warning('已达到最大重连次数，停止自动重连');
      return;
    }

    // 检查网络连接
    final isNetworkConnected = await NetworkUtils.isConnected();
    if (!isNetworkConnected) {
      Logger.debug('网络未连接，跳过重连');
      return;
    }

    // 检查是否有保存的连接状态
    final wasConnected = _storage.getConnectionState();
    if (!wasConnected) {
      return; // 没有保存的连接状态，不需要重连
    }

    // 检查当前连接状态
    if (_connectionManager.isConnected) {
      _reconnectAttempts = 0; // 重置计数
      return; // 已连接，不需要重连
    }

    // 尝试重连
    await _attemptReconnect();
  }

  /// 尝试重连
  Future<void> _attemptReconnect() async {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;

    try {
      Logger.info('尝试自动重连 (${_reconnectAttempts}/$_maxReconnectAttempts)');

      // 获取保存的订阅和节点
      final subscription = _storage.getCurrentSubscription();
      final node = _storage.getCurrentNode();

      if (subscription == null) {
        Logger.warning('没有保存的订阅信息，无法重连');
        disableAutoReconnect();
        return;
      }

      // 尝试重连
      await _connectionManager.connect(
        subscription: subscription,
        node: node,
      );

      Logger.info('自动重连成功');
      _reconnectAttempts = 0; // 重置计数
    } catch (e) {
      Logger.warning('自动重连失败: $e');
      // 继续尝试，直到达到最大次数
    } finally {
      _isReconnecting = false;
    }
  }

  /// 手动触发重连
  Future<void> reconnect() async {
    _reconnectAttempts = 0; // 重置计数
    await _attemptReconnect();
  }

  /// 释放资源
  void dispose() {
    disableAutoReconnect();
  }
}

