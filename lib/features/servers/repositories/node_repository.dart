import '../models/node.dart';

/// 节点仓库接口
abstract class NodeRepository {
  /// 获取节点列表
  Future<List<Node>> getNodes();

  /// 获取节点详情
  Future<Node> getNode(String id);

  /// 测试单个节点
  Future<NodeTestResult> testNode(String id);

  /// 批量测试节点
  Future<List<NodeTestResult>> batchTestNodes(List<String> nodeIds);
}

/// 节点测试结果
class NodeTestResult {
  final String nodeId;
  final int? latency;
  final double? downloadSpeed;
  final bool available;

  NodeTestResult({
    required this.nodeId,
    this.latency,
    this.downloadSpeed,
    required this.available,
  });
}

