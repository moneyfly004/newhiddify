import 'package:dio/dio.dart';
import '../../../data/remote/api_client.dart' hide NodeTestResult;
import 'node_repository.dart';
import '../models/node.dart';

/// 节点仓库实现
class NodeRepositoryImpl implements NodeRepository {
  final ApiClient _apiClient;

  NodeRepositoryImpl(this._apiClient);

  @override
  Future<List<Node>> getNodes() async {
    try {
      final response = await _apiClient.getNodes();
      final data = response.data;
      if (data is List) {
        return data.map((json) => Node.fromJson(json as Map<String, dynamic>)).toList();
      } else if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((json) => Node.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取节点列表失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<Node> getNode(String id) async {
    try {
      return await _apiClient.getNode(id);
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取节点详情失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<NodeTestResult> testNode(String id) async {
    try {
      final result = await _apiClient.testNode(id);
      return NodeTestResult(
        nodeId: result.nodeId,
        latency: result.latency,
        downloadSpeed: result.downloadSpeed,
        available: result.available,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '测试节点失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<List<NodeTestResult>> batchTestNodes(List<String> nodeIds) async {
    try {
      final results = await _apiClient.batchTestNodes({
        'node_ids': nodeIds,
      });
      return results.map((r) => NodeTestResult(
        nodeId: r.nodeId,
        latency: r.latency,
        downloadSpeed: r.downloadSpeed,
        available: r.available,
      )).toList();
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '批量测试节点失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }
}

