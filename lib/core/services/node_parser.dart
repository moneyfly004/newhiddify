import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../features/servers/models/node.dart';
import 'config_converter.dart';

/// 节点解析器
class NodeParser {
  /// 解析订阅内容为节点列表
  static List<Node> parseSubscription(String content) {
    try {
      final nodes = ConfigConverter.parseSubscription(content);
      return nodes.map((nodeData) => _parseNode(nodeData)).whereType<Node>().toList();
    } catch (e) {
      return [];
    }
  }

  /// 解析单个节点
  static Node? _parseNode(Map<String, dynamic> nodeData) {
    try {
      final normalized = ConfigConverter.normalizeNode(nodeData);
      
      return Node(
        id: _generateNodeId(normalized),
        name: normalized['name'] as String? ?? '未知节点',
        region: normalized['region'] as String?,
        type: normalized['type'] as String? ?? 'unknown',
        status: 'online',
        isActive: true,
        config: jsonEncode(normalized),
        latency: null,
        downloadSpeed: null,
      );
    } catch (e) {
      return null;
    }
  }

  /// 生成节点 ID
  static String _generateNodeId(Map<String, dynamic> node) {
    final key = '${node['server']}_${node['port']}_${node['type']}';
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 节点去重
  static List<Node> deduplicateNodes(List<Node> nodes) {
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

  /// 节点分组
  static Map<String, List<Node>> groupNodes(List<Node> nodes) {
    final groups = <String, List<Node>>{};

    for (final node in nodes) {
      final groupKey = node.region ?? '未分组';
      groups.putIfAbsent(groupKey, () => []).add(node);
    }

    return groups;
  }

  /// 合并多个订阅的节点
  static List<Node> mergeSubscriptions(List<List<Node>> subscriptionNodes) {
    final allNodes = <Node>[];
    
    for (final nodes in subscriptionNodes) {
      allNodes.addAll(nodes);
    }

    return deduplicateNodes(allNodes);
  }

  /// 按优先级排序节点
  static List<Node> sortNodesByPriority(List<Node> nodes) {
    // 优先显示：在线 > 有延迟数据 > 有速度数据
    return List.from(nodes)..sort((a, b) {
      // 在线状态优先
      if (a.isOnline != b.isOnline) {
        return a.isOnline ? -1 : 1;
      }
      
      // 有延迟数据的优先
      if (a.latency != null && b.latency == null) return -1;
      if (a.latency == null && b.latency != null) return 1;
      
      // 延迟低的优先
      if (a.latency != null && b.latency != null) {
        return a.latency!.compareTo(b.latency!);
      }
      
      // 有速度数据的优先
      if (a.downloadSpeed != null && b.downloadSpeed == null) return -1;
      if (a.downloadSpeed == null && b.downloadSpeed != null) return 1;
      
      // 速度高的优先
      if (a.downloadSpeed != null && b.downloadSpeed != null) {
        return b.downloadSpeed!.compareTo(a.downloadSpeed!);
      }
      
      return 0;
    });
  }
}

