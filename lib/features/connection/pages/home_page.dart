import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/connection_manager.dart';
import '../../../core/models/connection_mode.dart';
import '../../../core/services/speed_test_engine.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/models/auth_state.dart';
import '../../servers/cubit/subscription_cubit.dart';
import '../../servers/cubit/node_cubit.dart';
import '../../servers/repositories/subscription_repository.dart';
import '../../servers/repositories/node_repository.dart';
import '../../servers/models/subscription.dart';
import '../../servers/models/node.dart';
import '../widgets/server_list_widget.dart';
import '../widgets/connection_button.dart';
import '../widgets/mode_selector.dart';
import '../../../core/utils/error_handler.dart';
import '../../../ui/widgets/loading_overlay.dart';
import '../../../ui/widgets/network_status_indicator.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 主页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _connectionManager = getIt<ConnectionManager>();
  ConnectionMode _currentMode = ConnectionMode.rules;
  SubscriptionCubit? _subscriptionCubit;
  NodeCubit? _nodeCubit;

  @override
  void initState() {
    super.initState();
    // 检查登录状态，如果已登录则初始化订阅和节点
    _initializeIfAuthenticated();
  }

  void _initializeIfAuthenticated() {
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthAuthenticated) {
      _subscriptionCubit = SubscriptionCubit(getIt<SubscriptionRepository>());
      _nodeCubit = NodeCubit(getIt<NodeRepository>(), getIt<SpeedTestEngine>());
    }
  }

  @override
  void dispose() {
    _subscriptionCubit?.close();
    _nodeCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // 登录后自动初始化订阅和节点
          if (_subscriptionCubit == null) {
            setState(() {
              _subscriptionCubit = SubscriptionCubit(getIt<SubscriptionRepository>());
              _nodeCubit = NodeCubit(getIt<NodeRepository>(), getIt<SpeedTestEngine>());
            });
            // 自动加载订阅（会触发通用订阅获取）
            _subscriptionCubit?.loadSubscriptions();
          }
        } else if (state is AuthUnauthenticated) {
          // 登出后清理
          _subscriptionCubit?.close();
          _nodeCubit?.close();
          setState(() {
            _subscriptionCubit = null;
            _nodeCubit = null;
          });
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            if (authState is! AuthAuthenticated) {
              return _buildNotLoggedInView(context);
            }

            if (_subscriptionCubit == null || _nodeCubit == null) {
              return LoadingOverlay(
                isLoading: true,
                message: '正在初始化...',
                child: const SizedBox(),
              );
            }

            return MultiBlocProvider(
              providers: [
                BlocProvider.value(value: _subscriptionCubit!),
                BlocProvider.value(value: _nodeCubit!),
              ],
              child: _buildMainContent(context),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          // 连接状态指示灯
          StreamBuilder<ConnectionStatus>(
            stream: _connectionManager.statusStream,
            initialData: ConnectionStatus(
              isConnected: false,
              message: '未连接',
            ),
            builder: (context, snapshot) {
              final status = snapshot.data!;
              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.isConnected
                      ? CyberpunkTheme.neonGreen
                      : Colors.grey,
                  boxShadow: status.isConnected
                      ? CyberpunkTheme.neonGlow(CyberpunkTheme.neonGreen)
                      : null,
                ),
              );
            },
          ),
          const Text('MoneyFly'),
        ],
      ),
      actions: [
        const NetworkStatusIndicator(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.go('/settings'),
        ),
        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Text('登出'),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    context.read<AuthCubit>().logout();
                    _connectionManager.disconnect();
                  }
                },
              );
            }
            return IconButton(
              icon: const Icon(Icons.login),
              onPressed: () => context.go('/login'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotLoggedInView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vpn_key,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            '请先登录',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('立即登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: _connectionManager.statusStream,
      initialData: ConnectionStatus(
        isConnected: false,
        message: '未连接',
      ),
      builder: (context, connectionSnapshot) {
        final connectionStatus = connectionSnapshot.data!;

        return BlocBuilder<SubscriptionCubit, SubscriptionState>(
          builder: (context, subscriptionState) {
            if (subscriptionState is SubscriptionLoading) {
              return LoadingOverlay(
                isLoading: true,
                message: '加载订阅中...',
                child: const SizedBox(),
              );
            }

            if (subscriptionState is SubscriptionError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('加载订阅失败: ${subscriptionState.message}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<SubscriptionCubit>().loadSubscriptions();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }

            if (subscriptionState is! SubscriptionLoaded) {
              return const Center(child: Text('未知状态'));
            }

            final subscription = subscriptionState.currentSubscription;
            if (subscription == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('暂无可用订阅'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<SubscriptionCubit>().loadSubscriptions();
                      },
                      child: const Text('刷新'),
                    ),
                  ],
                ),
              );
            }

            return LoadingOverlay(
              isLoading: connectionStatus.isConnected && 
                        (connectionStatus.message.contains('连接中') || 
                         connectionStatus.message.contains('启动')),
              message: connectionStatus.message,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 订阅信息卡片
                    _buildSubscriptionCard(context, subscription),
                    
                    const SizedBox(height: 16),
                    
                    // 连接按钮
                    ConnectionButton(
                      isConnected: connectionStatus.isConnected,
                      onToggle: () => _handleConnectionToggle(
                        context,
                        subscription,
                        connectionStatus.isConnected,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                  // 模式选择器
                  ModeSelector(
                    currentMode: _currentMode,
                    onModeChanged: (mode) async {
                      setState(() {
                        _currentMode = mode;
                      });
                      // 如果已连接，应用新模式
                      if (connectionStatus.isConnected) {
                        try {
                          await _connectionManager.switchMode(mode);
                        } catch (e) {
                          if (mounted) {
                            ErrorHandler.showError(context, '切换模式失败: $e');
                          }
                        }
                      }
                    },
                  ),
                    
                    const SizedBox(height: 16),
                    
                    // 服务器列表
                    BlocBuilder<NodeCubit, NodeState>(
                      builder: (context, nodeState) {
                        if (nodeState is NodeLoaded) {
                          return ServerListWidget(
                            nodes: nodeState.nodes,
                            selectedNode: nodeState.selectedNode,
                            isAutoSelect: nodeState.isAutoSelect,
                            isTesting: nodeState.isTesting,
                            onNodeSelected: (node) {
                              context.read<NodeCubit>().selectNode(node);
                            },
                            onAutoSelect: () {
                              context.read<NodeCubit>().enableAutoSelect();
                            },
                          );
                        }
                        return LoadingOverlay(
                          isLoading: true,
                          message: '加载节点中...',
                          child: const SizedBox(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Subscription subscription,
  ) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final isExpired = subscription.isExpired;
    final remainingDays = subscription.remainingDays;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '订阅信息',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isExpired ? '已过期' : '有效',
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.calendar_today,
                    '到期时间',
                    dateFormat.format(subscription.expireTime),
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.devices,
                    '设备数量',
                    '${subscription.usedDevices ?? 0}/${subscription.deviceLimit}',
                  ),
                ),
              ],
            ),
            if (remainingDays > 0 && !isExpired) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: remainingDays / 30, // 假设订阅期为30天
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  remainingDays <= 7 ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '剩余 $remainingDays 天',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Future<void> _handleConnectionToggle(
    BuildContext context,
    Subscription subscription,
    bool isCurrentlyConnected,
  ) async {
    if (isCurrentlyConnected) {
      // 断开连接
      await _connectionManager.disconnect();
    } else {
      // 连接
      final nodeState = _nodeCubit?.state;
      if (nodeState is NodeLoaded && nodeState.nodes.isNotEmpty) {
        final selectedNode = nodeState.selectedNode ?? nodeState.nodes.first;
        
        debugPrint('[HomePage] 开始连接，订阅: ${subscription.id}, 节点: ${selectedNode.name}, 模式: $_currentMode');
        debugPrint('[HomePage] 可用节点数: ${nodeState.nodes.length}');
        
        try {
          await _connectionManager.connect(
            subscription: subscription,
            node: selectedNode,
            mode: _currentMode,
          );
        } catch (e) {
          debugPrint('[HomePage] 连接失败: $e');
          if (mounted) {
            ErrorHandler.showError(context, '连接失败: $e');
          }
        }
      } else {
        // 节点列表为空，提示用户
        debugPrint('[HomePage] 节点状态: $nodeState');
        if (mounted) {
          ErrorHandler.showError(
            context,
            '没有可用节点。请等待节点加载完成或刷新订阅。',
          );
        }
      }
    }
  }
}
