import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../utils/logger.dart';
import '../utils/cache_manager.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import 'node_parser.dart';

/// 增量更新器
class IncrementalUpdater {
  /// 计算订阅哈希
  static String calculateHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检测订阅变更
  static Future<SubscriptionChange> detectChanges(
    Subscription subscription,
    String newContent,
  ) async {
    // 获取旧哈希
    final oldHashKey = 'subscription_hash_${subscription.id}';
    final oldHash = await CacheManager.getCache<String>(oldHashKey);
    
    // 计算新哈希
    final newHash = calculateHash(newContent);
    
    // 如果哈希相同，没有变更
    if (oldHash == newHash) {
      return SubscriptionChange(
        hasChanges: false,
        addedNodes: [],
        removedNodes: [],
        modifiedNodes: [],
      );
    }

    // 解析新旧节点
    final oldNodes = await _getCachedNodes(subscription.id);
    final newNodes = NodeParser.parseSubscription(newContent);

    // 比较节点
    final oldNodeMap = {for (var n in oldNodes) n.id: n};
    final newNodeMap = {for (var n in newNodes) n.id: n};

    final addedNodes = <Node>[];
    final removedNodes = <Node>[];
    final modifiedNodes = <Node>[];

    // 检测新增和修改
    for (final newNode in newNodes) {
      final oldNode = oldNodeMap[newNode.id];
      if (oldNode == null) {
        addedNodes.add(newNode);
      } else if (_isNodeModified(oldNode, newNode)) {
        modifiedNodes.add(newNode);
      }
    }

    // 检测删除
    for (final oldNode in oldNodes) {
      if (!newNodeMap.containsKey(oldNode.id)) {
        removedNodes.add(oldNode);
      }
    }

    // 保存新哈希和节点
    await CacheManager.setCache(oldHashKey, newHash);
    await _cacheNodes(subscription.id, newNodes);

    return SubscriptionChange(
      hasChanges: true,
      addedNodes: addedNodes,
      removedNodes: removedNodes,
      modifiedNodes: modifiedNodes,
      newHash: newHash,
    );
  }

  /// 获取缓存的节点
  static Future<List<Node>> _getCachedNodes(String subscriptionId) async {
    final cacheKey = 'subscription_nodes_$subscriptionId';
    final cached = await CacheManager.getCache<List<dynamic>>(cacheKey);
    if (cached == null) return [];

    try {
      return cached
          .map((json) => Node.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 缓存节点
  static Future<void> _cacheNodes(String subscriptionId, List<Node> nodes) async {
    final cacheKey = 'subscription_nodes_$subscriptionId';
    await CacheManager.setCache(
      cacheKey,
      nodes.map((n) => n.toJson()).toList(),
      expiry: const Duration(days: 7),
    );
  }

  /// 检查节点是否被修改
  static bool _isNodeModified(Node oldNode, Node newNode) {
    return oldNode.name != newNode.name ||
           oldNode.config != newNode.config ||
           oldNode.region != newNode.region;
  }

  /// 应用增量更新
  static List<Node> applyIncrementalUpdate(
    List<Node> currentNodes,
    SubscriptionChange change,
  ) {
    final nodeMap = {for (var n in currentNodes) n.id: n};

    // 添加新节点
    for (final node in change.addedNodes) {
      nodeMap[node.id] = node;
    }

    // 更新修改的节点
    for (final node in change.modifiedNodes) {
      nodeMap[node.id] = node;
    }

    // 删除移除的节点
    for (final node in change.removedNodes) {
      nodeMap.remove(node.id);
    }

    return nodeMap.values.toList();
  }
}

/// 订阅变更
class SubscriptionChange {
  final bool hasChanges;
  final List<Node> addedNodes;
  final List<Node> removedNodes;
  final List<Node> modifiedNodes;
  final String? newHash;

  SubscriptionChange({
    required this.hasChanges,
    required this.addedNodes,
    required this.removedNodes,
    required this.modifiedNodes,
    this.newHash,
  });

  /// 变更总数
  int get totalChanges => addedNodes.length + removedNodes.length + modifiedNodes.length;
}

