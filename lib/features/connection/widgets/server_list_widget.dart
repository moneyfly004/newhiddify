import 'package:flutter/material.dart';
import '../../servers/models/node.dart';

/// 服务器列表组件
class ServerListWidget extends StatelessWidget {
  final List<Node> nodes;
  final Node? selectedNode;
  final bool isAutoSelect;
  final bool isTesting;
  final ValueChanged<Node> onNodeSelected;
  final VoidCallback onAutoSelect;

  const ServerListWidget({
    super.key,
    required this.nodes,
    this.selectedNode,
    this.isAutoSelect = true,
    this.isTesting = false,
    required this.onNodeSelected,
    required this.onAutoSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无服务器',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '服务器列表',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isTesting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 自动选择选项
          ListTile(
            leading: Icon(
              Icons.auto_awesome,
              color: isAutoSelect
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            title: const Text('自动选择'),
            subtitle: isAutoSelect && selectedNode != null
                ? Text('当前: ${selectedNode!.name}')
                : null,
            trailing: isAutoSelect
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
            selected: isAutoSelect,
            onTap: onAutoSelect,
          ),
          const Divider(height: 1),
          // 服务器列表
          ...nodes.map((node) => _buildServerItem(context, node)),
        ],
      ),
    );
  }

  Widget _buildServerItem(BuildContext context, Node node) {
    final isSelected = !isAutoSelect && selectedNode?.id == node.id;
    final isOnline = node.isOnline;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOnline
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
        ),
        child: Icon(
          isOnline ? Icons.cloud_done : Icons.cloud_off,
          color: isOnline ? Colors.green : Colors.grey,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              node.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (node.region != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                node.region!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              if (node.latency != null) ...[
                Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  node.latencyText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
              ],
              if (node.downloadSpeed != null) ...[
                Icon(Icons.download, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  node.speedText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      selected: isSelected,
      onTap: () => onNodeSelected(node),
    );
  }
}

