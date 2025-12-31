import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import 'node_parser.dart';

/// 订阅合并器
class SubscriptionMerger {
  /// 合并多个订阅
  static MergedSubscription mergeSubscriptions(
    List<Subscription> subscriptions,
    List<List<Node>> subscriptionNodes,
  ) {
    // 合并所有节点
    final allNodes = NodeParser.mergeSubscriptions(subscriptionNodes);
    
    // 去重
    final uniqueNodes = NodeParser.deduplicateNodes(allNodes);
    
    // 分组
    final groupedNodes = NodeParser.groupNodes(uniqueNodes);
    
    // 排序
    final sortedNodes = NodeParser.sortNodesByPriority(uniqueNodes);

    return MergedSubscription(
      subscriptions: subscriptions,
      nodes: sortedNodes,
      groupedNodes: groupedNodes,
      totalCount: uniqueNodes.length,
    );
  }

  /// 应用去重策略
  static List<Node> applyDeduplicationStrategy(
    List<Node> nodes,
    DeduplicationStrategy strategy,
  ) {
    switch (strategy) {
      case DeduplicationStrategy.keepFirst:
        return _keepFirst(nodes);
      case DeduplicationStrategy.keepLast:
        return _keepLast(nodes);
      case DeduplicationStrategy.keepBest:
        return _keepBest(nodes);
    }
  }

  static List<Node> _keepFirst(List<Node> nodes) {
    final seen = <String>{};
    final result = <Node>[];

    for (final node in nodes) {
      final key = '${node.name}_${node.id}';
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(node);
      }
    }

    return result;
  }

  static List<Node> _keepLast(List<Node> nodes) {
    final seen = <String, Node>{};

    for (final node in nodes) {
      final key = '${node.name}_${node.id}';
      seen[key] = node;
    }

    return seen.values.toList();
  }

  static List<Node> _keepBest(List<Node> nodes) {
    final groups = <String, List<Node>>{};

    for (final node in nodes) {
      final key = '${node.name}_${node.id}';
      groups.putIfAbsent(key, () => []).add(node);
    }

    final result = <Node>[];
    for (final group in groups.values) {
      // 选择最好的节点（在线 > 低延迟 > 高速度）
      group.sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        if (a.latency != null && b.latency != null) {
          return a.latency!.compareTo(b.latency!);
        }
        if (a.downloadSpeed != null && b.downloadSpeed != null) {
          return b.downloadSpeed!.compareTo(a.downloadSpeed!);
        }
        return 0;
      });
      result.add(group.first);
    }

    return result;
  }
}

/// 合并后的订阅
class MergedSubscription {
  final List<Subscription> subscriptions;
  final List<Node> nodes;
  final Map<String, List<Node>> groupedNodes;
  final int totalCount;

  MergedSubscription({
    required this.subscriptions,
    required this.nodes,
    required this.groupedNodes,
    required this.totalCount,
  });
}

/// 去重策略
enum DeduplicationStrategy {
  keepFirst,  // 保留第一个
  keepLast,   // 保留最后一个
  keepBest,   // 保留最好的
}

