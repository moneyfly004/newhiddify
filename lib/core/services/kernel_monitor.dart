import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import 'kernel_manager.dart';
import 'kernel_logger.dart';

/// 内核监控器 - 监控内核进程状态
class KernelMonitor {
  static const MethodChannel _channel = MethodChannel('com.proxyapp/kernel');
  final KernelManager _kernelManager;
  final KernelLogger _logger;
  Timer? _healthCheckTimer;
  final _monitorController = StreamController<KernelHealth>.broadcast();
  bool _autoRestartEnabled = false;
  int _restartCount = 0;
  static const int _maxRestartAttempts = 3;

  KernelMonitor(this._kernelManager, this._logger);

  /// 健康状态流
  Stream<KernelHealth> get healthStream => _monitorController.stream;

  /// 启动监控
  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(interval, (timer) {
      _checkHealth();
    });
    Logger.info('内核监控已启动，检查间隔: ${interval.inSeconds} 秒');
  }

  /// 停止监控
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    Logger.info('内核监控已停止');
  }

  /// 检查健康状态
  Future<void> _checkHealth() async {
    if (!_kernelManager.isRunning) {
      return;
    }

    try {
      final status = await _kernelManager.getKernelStatus();
      final isRunning = status['any_running'] as bool? ?? false;

      if (!isRunning) {
        Logger.warning('检测到内核进程已停止');
        _logger.addLog('内核进程已停止');
        _monitorController.add(KernelHealth(
          isHealthy: false,
          message: '内核进程已停止',
        ));
        
        // 自动重启
        if (_autoRestartEnabled && _restartCount < _maxRestartAttempts) {
          await _attemptRestart();
        }
      } else {
        _monitorController.add(KernelHealth(
          isHealthy: true,
          message: '内核运行正常',
        ));
      }
    } catch (e) {
      Logger.error('健康检查失败', e);
      _monitorController.add(KernelHealth(
        isHealthy: false,
        message: '健康检查失败: $e',
      ));
    }
  }

  /// 启用自动重启
  void enableAutoRestart() {
    _autoRestartEnabled = true;
    _restartCount = 0;
    Logger.info('已启用内核自动重启');
  }

  /// 禁用自动重启
  void disableAutoRestart() {
    _autoRestartEnabled = false;
    Logger.info('已禁用内核自动重启');
  }

  /// 尝试重启内核
  Future<void> _attemptRestart() async {
    _restartCount++;
    Logger.info('尝试重启内核 (${_restartCount}/$_maxRestartAttempts)');
    _logger.addLog('尝试重启内核 (${_restartCount}/$_maxRestartAttempts)');
    
    try {
      // 这里需要保存的配置来重启
      // 实际实现需要从 ConnectionManager 获取配置
      _monitorController.add(KernelHealth(
        isHealthy: false,
        message: '正在重启内核...',
      ));
      
      // TODO: 实现重启逻辑
      // await _kernelManager.restart();
      
      _restartCount = 0; // 重置计数
    } catch (e) {
      Logger.error('重启内核失败', e);
      _logger.addLog('重启内核失败: $e');
      
      if (_restartCount >= _maxRestartAttempts) {
        _monitorController.add(KernelHealth(
          isHealthy: false,
          message: '重启失败，已达到最大重试次数',
        ));
        _autoRestartEnabled = false;
      }
    }
  }

  /// 获取日志
  List<String> getLogs() => _logger.logs;

  /// 清除日志
  void clearLogs() => _logger.clearLogs();

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _monitorController.close();
  }
}

/// 内核健康状态
class KernelHealth {
  final bool isHealthy;
  final String message;
  final DateTime timestamp;

  KernelHealth({
    required this.isHealthy,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

