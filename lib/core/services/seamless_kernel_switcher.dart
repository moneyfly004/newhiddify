import 'dart:async';
import '../models/kernel_type.dart';
import '../utils/logger.dart';
import 'kernel_manager.dart';
import 'kernel_adapter.dart';

/// 无缝内核切换器
class SeamlessKernelSwitcher {
  final KernelManager _kernelManager;
  IKernelAdapter? _oldAdapter;
  IKernelAdapter? _newAdapter;
  String? _savedConfig;
  bool _isSwitching = false;

  SeamlessKernelSwitcher(this._kernelManager);

  /// 无缝切换内核
  Future<void> switchKernel({
    required KernelType targetKernel,
    required String newConfig,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isSwitching) {
      throw Exception('内核切换正在进行中');
    }

    if (_kernelManager.currentKernel == targetKernel) {
      Logger.info('目标内核与当前内核相同，无需切换');
      return;
    }

    _isSwitching = true;
    final oldKernel = _kernelManager.currentKernel;
    final wasRunning = _kernelManager.isRunning;

    try {
      Logger.info('开始无缝切换: ${oldKernel.displayName} -> ${targetKernel.displayName}');

      // 1. 保存当前状态和配置
      if (wasRunning) {
        _savedConfig = await _getCurrentConfig();
        _oldAdapter = KernelAdapterFactory.createAdapter(oldKernel, _kernelManager);
      }

      // 2. 创建新适配器
      _newAdapter = KernelAdapterFactory.createAdapter(targetKernel, _kernelManager);

      // 3. 验证新配置
      if (!_newAdapter!.validateConfig(newConfig)) {
        throw Exception('新内核配置验证失败');
      }

      // 4. 如果原来在运行，启动新内核（后台）
      if (wasRunning) {
        Logger.info('启动新内核（后台）');
        await _newAdapter!.start(newConfig);

        // 5. 等待新内核就绪
        Logger.info('等待新内核就绪...');
        final isReady = await _waitForKernelReady(_newAdapter!, timeout);
        
        if (!isReady) {
          throw Exception('新内核启动超时');
        }

        // 6. 验证新内核连接
        Logger.info('验证新内核连接...');
        final isConnected = await _verifyConnection(_newAdapter!);
        
        if (!isConnected) {
          throw Exception('新内核连接验证失败');
        }

        // 7. 停止旧内核
        Logger.info('停止旧内核');
        await _oldAdapter?.stop();
      } else {
        // 如果原来没运行，直接切换内核类型
        await _kernelManager.switchKernel(targetKernel);
      }

      Logger.info('内核切换成功');
    } catch (e) {
      Logger.error('内核切换失败', e);
      
      // 回滚：如果新内核已启动但验证失败，停止它
      if (_newAdapter != null && wasRunning) {
        try {
          await _newAdapter!.stop();
          // 尝试恢复旧内核
          if (_oldAdapter != null && _savedConfig != null) {
            await _oldAdapter!.start(_savedConfig!);
          }
        } catch (rollbackError) {
          Logger.error('回滚失败', rollbackError);
        }
      }
      
      rethrow;
    } finally {
      _isSwitching = false;
      _oldAdapter = null;
      _newAdapter = null;
      _savedConfig = null;
    }
  }

  /// 获取当前配置（从存储或状态中）
  Future<String> _getCurrentConfig() async {
    // 从 ConnectionManager 获取保存的配置
    // 这里需要实际实现，暂时返回空字符串
    // TODO: 从 StorageService 或 ConnectionManager 获取保存的配置
    return '';
  }

  /// 等待内核就绪
  Future<bool> _waitForKernelReady(IKernelAdapter adapter, Duration timeout) async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final status = await adapter.getStatus();
        final isRunning = status['any_running'] as bool? ?? false;
        
        if (isRunning) {
          // 额外等待一小段时间确保完全就绪
          await Future.delayed(const Duration(milliseconds: 500));
          return true;
        }
      } catch (e) {
        // 继续等待
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return false;
  }

  /// 验证连接
  Future<bool> _verifyConnection(IKernelAdapter adapter) async {
    try {
      final status = await adapter.getStatus();
      final isRunning = status['any_running'] as bool? ?? false;
      
      if (!isRunning) return false;

      // 可以添加更详细的连接测试
      // 例如：测试代理端口是否可访问
      
      return true;
    } catch (e) {
      Logger.error('连接验证失败', e);
      return false;
    }
  }

  /// 是否正在切换
  bool get isSwitching => _isSwitching;
}

