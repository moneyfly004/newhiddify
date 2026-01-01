import 'dart:async';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import '../../features/servers/repositories/subscription_repository.dart';
import 'kernel_manager.dart';
import 'kernel_config_generator.dart';
import 'permission_service.dart';
import 'foreground_service.dart';
import 'storage_service.dart';
import 'base64_subscription_parser.dart';
import 'kernel_switcher_with_conversion.dart';
import 'settings_service.dart';
import '../models/kernel_type.dart';
import '../models/connection_mode.dart';
import '../models/app_settings.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../utils/network_utils.dart';

/// 连接管理器
class ConnectionManager {
  final KernelManager _kernelManager;
  final SubscriptionRepository _subscriptionRepository;
  final StorageService? _storage;
  late final KernelSwitcherWithConversion _kernelSwitcher;

  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  Subscription? _currentSubscription;
  Node? _currentNode;
  ConnectionMode _currentMode = ConnectionMode.rules;

  ConnectionManager(
    this._kernelManager,
    this._subscriptionRepository, [
    this._storage,
  ]) {
    // 恢复连接模式
    if (_storage != null) {
      _currentMode = _storage!.getConnectionMode();
    }
    
    // 初始化内核切换器
    _kernelSwitcher = KernelSwitcherWithConversion(
      _kernelManager,
      _subscriptionRepository,
    );
    // 监听内核状态变化
    _kernelManager.statusStream.listen((status) {
      _connectionController.add(ConnectionStatus(
        isConnected: status.isRunning,
        subscription: _currentSubscription,
        node: _currentNode,
        message: status.message,
        error: status.error,
      ));
    });
  }

  /// 连接状态流
  Stream<ConnectionStatus> get statusStream => _connectionController.stream;

  /// 当前订阅
  Subscription? get currentSubscription => _currentSubscription;

  /// 当前节点
  Node? get currentNode => _currentNode;

  /// 是否已连接
  bool get isConnected => _kernelManager.isRunning;

  /// 连接
  Future<void> connect({
    required Subscription subscription,
    Node? node,
    KernelType? kernelType,
    ConnectionMode? mode,
  }) async {
    try {
      debugPrint('[ConnectionManager] 开始连接流程');
      debugPrint('[ConnectionManager] 订阅: ${subscription.id}, 节点: ${node?.name ?? "自动"}, 模式: ${mode?.name ?? _currentMode.name}');
      
      // 检查网络连接
      final isConnected = await NetworkUtils.isConnected();
      debugPrint('[ConnectionManager] 网络连接状态: $isConnected');
      if (!isConnected) {
        throw Exception('网络未连接，请检查网络设置');
      }

      // 检查 VPN 权限
      final hasVpnPermission = await PermissionService.checkVpnPermission();
      debugPrint('[ConnectionManager] VPN 权限状态: $hasVpnPermission');
      if (!hasVpnPermission) {
        debugPrint('[ConnectionManager] 请求 VPN 权限...');
        final granted = await PermissionService.requestVpnPermission();
        debugPrint('[ConnectionManager] VPN 权限授予: $granted');
        if (!granted) {
          throw Exception('需要 VPN 权限才能连接');
        }
      }

      // 启动前台服务
      debugPrint('[ConnectionManager] 启动前台服务...');
      final serviceStarted = await ForegroundService.startService(
        title: 'MoneyFly',
        content: '正在连接...',
      );
      debugPrint('[ConnectionManager] 前台服务启动结果: $serviceStarted');
      if (!serviceStarted) {
        debugPrint('[ConnectionManager] 警告: 前台服务启动失败，但继续连接流程');
      }

      // 切换内核（如果指定且不同）
      if (kernelType != null && kernelType != _kernelManager.currentKernel) {
        // 使用带格式转换的切换器
        await _switchKernelWithConversion(
          targetKernel: kernelType,
          subscription: subscription,
          node: node,
          mode: mode ?? _currentMode,
        );
      }

      // 更新连接模式（如果指定）
      if (mode != null) {
        _currentMode = mode;
        await _storage?.saveConnectionMode(mode);
      }

      // 获取通用订阅配置（Base64 编码的节点）
      // 注意：只使用通用订阅格式，不支持 Clash 格式
      debugPrint('[ConnectionManager] 获取通用订阅配置...');
      
      // 优先使用 universalUrl，如果没有则使用 subscriptionUrl
      final subscriptionUrlToUse = subscription.universalUrl ?? subscription.subscriptionUrl;
      debugPrint('[ConnectionManager] 订阅URL: $subscriptionUrlToUse');
      debugPrint('[ConnectionManager] subscriptionUrl: ${subscription.subscriptionUrl}');
      debugPrint('[ConnectionManager] universalUrl: ${subscription.universalUrl}');
      
      if (subscriptionUrlToUse.isEmpty) {
        throw Exception('订阅URL为空，无法获取配置');
      }
      final base64Content = await _subscriptionRepository.getUniversalConfig(
        subscriptionUrlToUse,
      );
      debugPrint('[ConnectionManager] 订阅配置获取成功，长度: ${base64Content.length}');

      // 从 Base64 订阅生成配置
      debugPrint('[ConnectionManager] 生成内核配置...');
      
      // 获取设置（服务模式、允许访问、混合端口等）
      final settingsService = SettingsService.instance;
      await settingsService.initialize();
      final settings = settingsService.settings;
      final isVpnMode = settings.serviceMode == ServiceMode.vpn;
      final allowAccess = settings.allowAccess;
      final mixedPort = settings.mixedPort;
      
      final bypassLan = settings.bypassLan;
      final remoteDnsList = settings.remoteDns.split('\n')
          .where((dns) => dns.trim().isNotEmpty && !dns.trim().startsWith('#'))
          .map((dns) => dns.trim())
          .toList();
      final directDnsList = settings.directDns.split('\n')
          .where((dns) => dns.trim().isNotEmpty && !dns.trim().startsWith('#'))
          .map((dns) => dns.trim())
          .toList();
      
      debugPrint('[ConnectionManager] 服务模式: ${isVpnMode ? "VPN" : "代理"}');
      debugPrint('[ConnectionManager] 允许访问: $allowAccess');
      debugPrint('[ConnectionManager] 混合端口: $mixedPort');
      debugPrint('[ConnectionManager] 绕过局域网: $bypassLan');
      debugPrint('[ConnectionManager] 远程 DNS: $remoteDnsList');
      debugPrint('[ConnectionManager] 直连 DNS: $directDnsList');
      
      final config = await _generateConfigFromBase64(
        base64Content,
        subscription,
        mode ?? _currentMode,
        node,
        isVpnMode: isVpnMode,
        allowAccess: allowAccess,
        mixedPort: mixedPort,
        bypassLan: bypassLan,
        remoteDns: remoteDnsList.isNotEmpty ? remoteDnsList : ['https://dns.google/dns-query'],
        directDns: directDnsList.isNotEmpty ? directDnsList : ['https://223.5.5.5/dns-query'],
      );
      debugPrint('[ConnectionManager] 配置生成完成，长度: ${config.length}');

      // 启动内核
      debugPrint('[ConnectionManager] 启动内核: ${_kernelManager.currentKernel.displayName}');
      await _kernelManager.startKernel(config);
      debugPrint('[ConnectionManager] 内核启动成功');

      _currentSubscription = subscription;
      _currentNode = node;

      // 保存状态
      await _storage?.saveCurrentSubscription(subscription);
      if (node != null) {
        await _storage?.saveCurrentNode(node);
      }
      await _storage?.saveConnectionState(true);

      // 更新前台服务通知
      await ForegroundService.updateNotification(
        title: 'MoneyFly',
        content: '已连接 - ${node?.name ?? "自动"}',
      );

      Logger.info('连接成功: ${node?.name ?? "自动"}');
      
      _connectionController.add(ConnectionStatus(
        isConnected: true,
        subscription: subscription,
        node: node,
        message: '连接成功',
      ));
    } catch (e) {
      // 连接失败，停止前台服务
      await ForegroundService.stopService();
      
      Logger.error('连接失败', e);

      _connectionController.add(ConnectionStatus(
        isConnected: false,
        subscription: subscription,
        node: node,
        message: '连接失败',
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _kernelManager.stopKernel();
      
      // 停止前台服务
      await ForegroundService.stopService();
      
      _currentSubscription = null;
      _currentNode = null;

      // 清除保存的状态
      await _storage?.saveConnectionState(false);

      _connectionController.add(ConnectionStatus(
        isConnected: false,
        subscription: null,
        node: null,
        message: '已断开连接',
      ));
    } catch (e) {
      _connectionController.add(ConnectionStatus(
        isConnected: false,
        subscription: _currentSubscription,
        node: _currentNode,
        message: '断开连接失败',
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// 切换节点
  Future<void> switchNode(Node node) async {
    if (_currentSubscription == null) {
      throw Exception('请先选择订阅');
    }

    await connect(
      subscription: _currentSubscription!,
      node: node,
      mode: _currentMode,
    );
  }

  /// 切换连接模式
  Future<void> switchMode(ConnectionMode mode) async {
    if (_currentMode == mode) return;

    _currentMode = mode;
    await _storage?.saveConnectionMode(mode);

    // 如果正在连接，需要重新连接以应用新模式
    if (isConnected && _currentSubscription != null) {
      await connect(
        subscription: _currentSubscription!,
        node: _currentNode,
        mode: mode,
      );
    }
  }

  /// 获取当前连接模式
  ConnectionMode get currentMode => _currentMode;

  /// 从 Base64 订阅生成配置
  /// 如果提供了 selectedNode，直接使用它；否则从 Base64 订阅解析节点
  Future<String> _generateConfigFromBase64(
    String base64Content,
    Subscription subscription,
    ConnectionMode mode,
    Node? selectedNode, {
    bool? isVpnMode,
    bool? allowAccess,
    int? mixedPort,
    bool? bypassLan,
    List<String>? remoteDns,
    List<String>? directDns,
  }) async {
    Node? targetNode = selectedNode;
    
    // 如果提供了节点，直接使用；否则从 Base64 订阅解析
    if (targetNode == null) {
      debugPrint('[ConnectionManager] 未提供节点，从 Base64 订阅解析...');
      debugPrint('[ConnectionManager] Base64 内容长度: ${base64Content.length}');
      final nodes = Base64SubscriptionParser.parseBase64Subscription(base64Content);
      
      debugPrint('[ConnectionManager] 解析结果: ${nodes.length} 个节点');
      if (nodes.isEmpty) {
        debugPrint('[ConnectionManager] 错误: 订阅中没有可用节点');
        throw Exception('订阅中没有可用节点。请确保订阅有效且包含可用节点。');
      }
      
      debugPrint('[ConnectionManager] 节点列表:');
      for (var i = 0; i < nodes.length; i++) {
        debugPrint('[ConnectionManager]   ${i + 1}. ${nodes[i].name} (${nodes[i].type})');
      }
      
      targetNode = nodes.first;
    } else {
      debugPrint('[ConnectionManager] 使用提供的节点: ${targetNode.name} (${targetNode.type})');
    }

    // 根据当前内核类型生成配置
    // 注意：节点配置已经是标准格式，会根据内核类型自动转换
    return await KernelConfigGenerator.generateConfig(
      kernelType: _kernelManager.currentKernel,
      subscription: subscription,
      mode: mode,
      selectedNode: targetNode,
      rawConfig: null, // 不使用原始配置，直接生成
      isVpnMode: isVpnMode,
      allowAccess: allowAccess,
      mixedPort: mixedPort,
      bypassLan: bypassLan,
      remoteDns: remoteDns,
      directDns: directDns,
    );
  }

  /// 带格式转换的内核切换
  Future<void> _switchKernelWithConversion({
    required KernelType targetKernel,
    required Subscription subscription,
    Node? node,
    required ConnectionMode mode,
  }) async {
    try {
      Logger.info('开始切换内核并转换格式: ${_kernelManager.currentKernel.displayName} -> ${targetKernel.displayName}');
      
      await _kernelSwitcher.switchKernel(
        targetKernel: targetKernel,
        subscription: subscription,
        node: node,
        mode: mode,
      );
      
      Logger.info('内核切换成功，格式已转换');
    } catch (e) {
      Logger.error('内核切换失败', e);
      rethrow;
    }
  }

  /// 释放资源
  void dispose() {
    _connectionController.close();
  }
}

/// 连接状态
class ConnectionStatus {
  final bool isConnected;
  final Subscription? subscription;
  final Node? node;
  final String message;
  final String? error;

  ConnectionStatus({
    required this.isConnected,
    this.subscription,
    this.node,
    required this.message,
    this.error,
  });
}

