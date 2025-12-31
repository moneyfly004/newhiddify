import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../ui/theme/cyberpunk_theme.dart';
import '../cubit/subscription_cubit.dart';
import '../cubit/node_cubit.dart';
import '../models/subscription.dart';
import '../models/node.dart';
import '../../connection/widgets/server_list_widget.dart';

/// 服务器列表页面
class ServersListPage extends StatelessWidget {
  const ServersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器列表'),
      ),
      body: BlocBuilder<SubscriptionCubit, SubscriptionState>(
        builder: (context, subscriptionState) {
          if (subscriptionState is SubscriptionLoaded) {
            return Column(
              children: [
                // 订阅信息
                _buildSubscriptionSection(context, subscriptionState),
                
                // 服务器列表
                Expanded(
                  child: BlocBuilder<NodeCubit, NodeState>(
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
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildSubscriptionSection(
    BuildContext context,
    SubscriptionLoaded state,
  ) {
    final subscription = state.currentSubscription;
    if (subscription == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: CyberpunkTheme.neonGradient(),
        child: const Text('暂无可用订阅'),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: CyberpunkTheme.neonGradient(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subscription.subscriptionUrl,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: subscription.isExpired
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: subscription.isExpired
                        ? Colors.red
                        : Colors.green,
                    width: 1,
                  ),
                ),
                child: Text(
                  subscription.isExpired ? '已过期' : '有效',
                  style: TextStyle(
                    color: subscription.isExpired
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  Icons.calendar_today,
                  '到期时间',
                  subscription.expireTime.toString().split(' ')[0],
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  Icons.devices,
                  '设备',
                  '${subscription.usedDevices ?? 0}/${subscription.deviceLimit}',
                ),
              ),
            ],
          ),
        ],
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
            Icon(icon, size: 16, color: CyberpunkTheme.neonCyan),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

