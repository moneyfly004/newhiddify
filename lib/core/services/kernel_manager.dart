import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/kernel_type.dart';
import '../utils/logger.dart';
import 'storage_service.dart';

/// 内核管理器
class KernelManager {
  static const MethodChannel _channel = MethodChannel('com.proxyapp/kernel');
  
  final StorageService? _storage;
  KernelType _currentKernel;
  bool _isRunning = false;
  final _statusController = StreamController<KernelStatus>.broadcast();

  KernelManager([this._storage]) : _currentKernel = _storage?.getKernelType() ?? KernelType.singbox {
    // 恢复内核状态
    _restoreState();
  }

  /// 当前内核类型
  KernelType get currentKernel => _currentKernel;

  /// 是否运行中
  bool get isRunning => _isRunning;

  /// 状态流
  Stream<KernelStatus> get statusStream => _statusController.stream;

  /// 切换内核
  Future<void> switchKernel(KernelType type) async {
    if (_currentKernel == type) return;

    Logger.info('切换内核: ${_currentKernel.displayName} -> ${type.displayName}');

    // 如果正在运行，先停止当前内核
    if (_isRunning) {
      await stopKernel();
    }

    _currentKernel = type;
    
    // 保存内核类型
    await _storage?.saveKernelType(type);
    
    _statusController.add(KernelStatus(
      kernel: type,
      isRunning: false,
      message: '已切换到 ${type.displayName}',
    ));
  }

  /// 启动内核
  Future<void> startKernel(String config) async {
    try {
      if (_isRunning) {
        await stopKernel();
      }

      final method = _currentKernel == KernelType.singbox
          ? 'start_singbox'
          : 'start_mihomo';

      final result = await _channel.invokeMethod<bool>(
        method,
        {'config': config},
      );

      if (result == true) {
        _isRunning = true;
        _statusController.add(KernelStatus(
          kernel: _currentKernel,
          isRunning: true,
          message: '${_currentKernel.displayName} 已启动',
        ));
      } else {
        throw Exception('启动内核失败');
      }
    } on PlatformException catch (e) {
      _isRunning = false;
      _statusController.add(KernelStatus(
        kernel: _currentKernel,
        isRunning: false,
        message: '启动失败: ${e.message}',
        error: e.message,
      ));
      rethrow;
    }
  }

  /// 停止内核
  Future<void> stopKernel() async {
    try {
      await _channel.invokeMethod('stop_proxy');
      _isRunning = false;
      _statusController.add(KernelStatus(
        kernel: _currentKernel,
        isRunning: false,
        message: '已停止',
      ));
    } on PlatformException catch (e) {
      _statusController.add(KernelStatus(
        kernel: _currentKernel,
        isRunning: false,
        message: '停止失败: ${e.message}',
        error: e.message,
      ));
      rethrow;
    }
  }

  /// 获取内核状态
  Future<Map<String, dynamic>> getKernelStatus() async {
    try {
      final status = await _channel.invokeMethod<Map<Object?, Object?>>(
        'get_kernel_status',
      );
      return Map<String, dynamic>.from(status ?? {});
    } on PlatformException {
      return {};
    }
  }

  /// 恢复状态
  Future<void> _restoreState() async {
    // 检查是否有保存的连接状态
    final wasConnected = _storage?.getConnectionState() ?? false;
    if (wasConnected) {
      Logger.info('检测到上次连接状态');
      // 不自动重连，让用户手动操作
    }
  }

  /// 重启内核（需要配置）
  Future<void> restartKernel(String config) async {
    Logger.info('重启内核');
    try {
      await stopKernel();
      await Future.delayed(const Duration(seconds: 1));
      await startKernel(config);
    } catch (e) {
      Logger.error('重启内核失败', e);
      rethrow;
    }
  }

  /// 重新加载配置
  Future<void> reloadConfig(String config) async {
    if (!_isRunning) {
      await startKernel(config);
      return;
    }

    try {
      final method = _currentKernel == KernelType.singbox
          ? 'reload_singbox'
          : 'reload_mihomo';
      
      await _channel.invokeMethod(method, {'config': config});
      
      _statusController.add(KernelStatus(
        kernel: _currentKernel,
        isRunning: true,
        message: '配置已重新加载',
      ));
    } on PlatformException catch (e) {
      Logger.error('重新加载配置失败', e);
      // 如果重新加载失败，尝试重启
      await restartKernel(config);
    }
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
  }
}

/// 内核状态
class KernelStatus {
  final KernelType kernel;
  final bool isRunning;
  final String message;
  final String? error;

  KernelStatus({
    required this.kernel,
    required this.isRunning,
    required this.message,
    this.error,
  });
}
