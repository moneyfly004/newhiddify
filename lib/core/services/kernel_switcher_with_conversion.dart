import 'dart:async';
import '../models/kernel_type.dart';
import '../utils/logger.dart';
import 'kernel_manager.dart';
import 'kernel_adapter.dart';
import 'config_converter.dart';
import 'seamless_kernel_switcher.dart';
import 'base64_subscription_parser.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import '../../features/servers/repositories/subscription_repository.dart';
import '../models/connection_mode.dart';
import 'kernel_config_generator.dart';

/// 带格式转换的内核切换器
class KernelSwitcherWithConversion {
  final KernelManager _kernelManager;
  final SubscriptionRepository _subscriptionRepository;
  final SeamlessKernelSwitcher _seamlessSwitcher;
  Subscription? _currentSubscription;
  Node? _currentNode;
  ConnectionMode _currentMode = ConnectionMode.rules;

  KernelSwitcherWithConversion(
    this._kernelManager,
    this._subscriptionRepository,
  ) : _seamlessSwitcher = SeamlessKernelSwitcher(_kernelManager);

  /// 切换内核（带格式转换）
  Future<void> switchKernel({
    required KernelType targetKernel,
    required Subscription subscription,
    Node? node,
    ConnectionMode? mode,
  }) async {
    if (_kernelManager.currentKernel == targetKernel) {
      Logger.info('目标内核与当前内核相同，无需切换');
      return;
    }

    try {
      Logger.info('开始切换内核: ${_kernelManager.currentKernel.displayName} -> ${targetKernel.displayName}');

      // 1. 获取当前配置（Base64 订阅）
      final base64Content = await _getCurrentSubscriptionContent(subscription);
      
      // 2. 解析节点
      final nodes = Base64SubscriptionParser.parseBase64Subscription(base64Content);
      if (nodes.isEmpty) {
        throw Exception('订阅中没有可用节点');
      }

      // 3. 选择节点
      final targetNode = node ?? _currentNode ?? nodes.first;

      // 4. 生成新内核配置
      final newConfig = await KernelConfigGenerator.generateConfig(
        kernelType: targetKernel,
        subscription: subscription,
        mode: mode ?? _currentMode,
        selectedNode: targetNode,
        rawConfig: null,
      );

      // 5. 执行无缝切换
      await _seamlessSwitcher.switchKernel(
        targetKernel: targetKernel,
        newConfig: newConfig,
      );

      // 6. 更新状态
      _currentSubscription = subscription;
      _currentNode = targetNode;
      if (mode != null) {
        _currentMode = mode;
      }

      Logger.info('内核切换成功，已转换为 ${targetKernel.displayName} 格式');
    } catch (e) {
      Logger.error('内核切换失败', e);
      rethrow;
    }
  }

  /// 获取当前订阅内容
  Future<String> _getCurrentSubscriptionContent(Subscription subscription) async {
    // 获取通用订阅（Base64 格式）
    return await _subscriptionRepository.getUniversalConfig(
      subscription.subscriptionUrl,
    );
  }
}

