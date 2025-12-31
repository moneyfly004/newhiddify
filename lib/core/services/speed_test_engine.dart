import 'dart:async';
import '../../features/servers/models/node.dart';
import '../../features/servers/repositories/node_repository.dart';

/// 测速结果
class SpeedTestResult {
  final Node node;
  final int? latency;
  final double? downloadSpeed;
  final bool available;
  final DateTime testTime;

  SpeedTestResult({
    required this.node,
    this.latency,
    this.downloadSpeed,
    required this.available,
    DateTime? testTime,
  }) : testTime = testTime ?? DateTime.now();

  /// 综合评分（0-100）
  double get score {
    double score = 0;

    // 延迟评分（40分）
    if (latency != null) {
      if (latency! < 50) {
        score += 40;
      } else if (latency! < 100) {
        score += 30;
      } else if (latency! < 200) {
        score += 20;
      } else if (latency! < 500) {
        score += 10;
      }
    }

    // 速度评分（60分）
    if (downloadSpeed != null) {
      if (downloadSpeed! >= 10) {
        score += 60;
      } else if (downloadSpeed! >= 5) {
        score += 45;
      } else if (downloadSpeed! >= 1) {
        score += 30;
      } else if (downloadSpeed! >= 0.5) {
        score += 15;
      }
    }

    // 可用性
    if (!available) {
      score = 0;
    }

    return score;
  }
}

/// 测速引擎
class SpeedTestEngine {
  final NodeRepository? _nodeRepository;
  final _testController = StreamController<SpeedTestProgress>.broadcast();
  bool _isTesting = false;

  SpeedTestEngine([this._nodeRepository]);

  /// 测速进度流
  Stream<SpeedTestProgress> get progressStream => _testController.stream;

  /// 是否正在测速
  bool get isTesting => _isTesting;

  /// 测试所有节点
  Future<List<SpeedTestResult>> testAllNodes(List<Node> nodes) async {
    if (_isTesting) {
      throw Exception('测速正在进行中');
    }

    _isTesting = true;
    final results = <SpeedTestResult>[];

    try {
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        
        _testController.add(SpeedTestProgress(
          current: i + 1,
          total: nodes.length,
          node: node,
          message: '正在测试 ${node.name}...',
        ));

        try {
          final result = await _testSingleNode(node);
          results.add(result);

          _testController.add(SpeedTestProgress(
            current: i + 1,
            total: nodes.length,
            node: node,
            result: result,
            message: '${node.name} 测试完成',
          ));
        } catch (e) {
          final errorResult = SpeedTestResult(
            node: node,
            available: false,
          );
          results.add(errorResult);

          _testController.add(SpeedTestProgress(
            current: i + 1,
            total: nodes.length,
            node: node,
            result: errorResult,
            message: '${node.name} 测试失败: $e',
          ));
        }

        // 避免请求过快
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 按评分排序
      results.sort((a, b) => b.score.compareTo(a.score));

      _testController.add(SpeedTestProgress(
        current: nodes.length,
        total: nodes.length,
        message: '测速完成',
        isComplete: true,
      ));

      return results;
    } finally {
      _isTesting = false;
    }
  }

  /// 测试单个节点
  Future<SpeedTestResult> _testSingleNode(Node node) async {
    try {
      if (_nodeRepository == null) {
        throw Exception('NodeRepository 未初始化');
      }
      // 使用后端 API 测试节点
      final testResult = await _nodeRepository!.testNode(node.id);

      return SpeedTestResult(
        node: node,
        latency: testResult.latency,
        downloadSpeed: testResult.downloadSpeed,
        available: testResult.available,
      );
    } catch (e) {
      return SpeedTestResult(
        node: node,
        available: false,
      );
    }
  }

  /// 批量测试节点
  Future<List<SpeedTestResult>> batchTestNodes(List<Node> nodes) async {
    if (_isTesting) {
      throw Exception('测速正在进行中');
    }

    _isTesting = true;

    try {
      _testController.add(SpeedTestProgress(
        current: 0,
        total: nodes.length,
        message: '开始批量测试...',
      ));

      if (_nodeRepository == null) {
        throw Exception('NodeRepository 未初始化');
      }
      final nodeIds = nodes.map((n) => n.id).toList();
      final testResults = await _nodeRepository!.batchTestNodes(nodeIds);

      final results = <SpeedTestResult>[];
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final testResult = testResults.firstWhere(
          (r) => r.nodeId == node.id,
          orElse: () => NodeTestResult(
            nodeId: node.id,
            available: false,
          ),
        );

        results.add(SpeedTestResult(
          node: node,
          latency: testResult.latency,
          downloadSpeed: testResult.downloadSpeed,
          available: testResult.available,
        ));

        _testController.add(SpeedTestProgress(
          current: i + 1,
          total: nodes.length,
          node: node,
          result: results.last,
          message: '${node.name} 测试完成',
        ));
      }

      // 按评分排序
      results.sort((a, b) => b.score.compareTo(a.score));

      _testController.add(SpeedTestProgress(
        current: nodes.length,
        total: nodes.length,
        message: '批量测速完成',
        isComplete: true,
      ));

      return results;
    } finally {
      _isTesting = false;
    }
  }

  /// 释放资源
  void dispose() {
    _testController.close();
  }
}

/// 测速进度
class SpeedTestProgress {
  final int current;
  final int total;
  final Node? node;
  final SpeedTestResult? result;
  final String message;
  final bool isComplete;

  SpeedTestProgress({
    required this.current,
    required this.total,
    this.node,
    this.result,
    required this.message,
    this.isComplete = false,
  });

  /// 进度百分比
  double get progress => total > 0 ? current / total : 0.0;
}

