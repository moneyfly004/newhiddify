import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/node.dart';
import '../repositories/node_repository.dart';
import '../../../core/services/speed_test_engine.dart';
// SpeedTestResult 定义在 speed_test_engine.dart 中

/// 节点状态
abstract class NodeState extends Equatable {
  const NodeState();

  @override
  List<Object?> get props => [];
}

/// 节点加载中
class NodeLoading extends NodeState {}

/// 节点加载成功
class NodeLoaded extends NodeState {
  final List<Node> nodes;
  final Node? selectedNode;
  final bool isAutoSelect;
  final bool isTesting;

  const NodeLoaded({
    required this.nodes,
    this.selectedNode,
    this.isAutoSelect = true,
    this.isTesting = false,
  });

  @override
  List<Object?> get props => [nodes, selectedNode, isAutoSelect, isTesting];

  NodeLoaded copyWith({
    List<Node>? nodes,
    Node? selectedNode,
    bool? isAutoSelect,
    bool? isTesting,
  }) {
    return NodeLoaded(
      nodes: nodes ?? this.nodes,
      selectedNode: selectedNode ?? this.selectedNode,
      isAutoSelect: isAutoSelect ?? this.isAutoSelect,
      isTesting: isTesting ?? this.isTesting,
    );
  }
}

/// 节点错误
class NodeError extends NodeState {
  final String message;

  const NodeError(this.message);

  @override
  List<Object?> get props => [message];
}

/// 节点 Cubit
class NodeCubit extends Cubit<NodeState> {
  final NodeRepository _repository;
  final SpeedTestEngine _speedTestEngine;
  Timer? _autoTestTimer;
  bool _isAutoTesting = false;

  NodeCubit(this._repository, this._speedTestEngine)
      : super(NodeLoading()) {
    loadNodes();
    _startAutoTesting();
  }

  /// 加载节点列表
  Future<void> loadNodes() async {
    try {
      emit(NodeLoading());
      final nodes = await _repository.getNodes();
      
      // 如果有节点，自动选择最优节点
      Node? bestNode;
      if (nodes.isNotEmpty) {
        // 优先选择已测速的节点
        final testedNodes = nodes.where((n) => n.latency != null).toList();
        if (testedNodes.isNotEmpty) {
          testedNodes.sort((a, b) {
            final scoreA = _calculateScore(a);
            final scoreB = _calculateScore(b);
            return scoreB.compareTo(scoreA);
          });
          bestNode = testedNodes.first;
        } else {
          bestNode = nodes.first;
        }
      }

      emit(NodeLoaded(
        nodes: nodes,
        selectedNode: bestNode,
        isAutoSelect: true,
      ));
    } catch (e) {
      emit(NodeError(e.toString()));
    }
  }

  /// 选择节点
  void selectNode(Node node) {
    final currentState = state;
    if (currentState is NodeLoaded) {
      emit(currentState.copyWith(
        selectedNode: node,
        isAutoSelect: false,
      ));
    }
  }

  /// 启用自动选择
  void enableAutoSelect() {
    final currentState = state;
    if (currentState is NodeLoaded) {
      _selectBestNode(currentState.nodes);
    }
  }

  /// 开始自动测速
  void _startAutoTesting() {
    // 每5分钟自动测速一次
    _autoTestTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isAutoTesting) {
        _autoTest();
      }
    });
  }

  /// 自动测速
  Future<void> _autoTest() async {
    if (_isAutoTesting) return;
    
    final currentState = state;
    if (currentState is! NodeLoaded || currentState.nodes.isEmpty) return;

    _isAutoTesting = true;
    
    try {
      emit(currentState.copyWith(isTesting: true));

      // 批量测试所有节点
      final results = await _speedTestEngine.batchTestNodes(currentState.nodes);

      // 更新节点测速结果
      final updatedNodes = currentState.nodes.map((node) {
        final result = results.firstWhere(
          (r) => r.node.id == node.id,
          orElse: () => SpeedTestResult(
            node: node,
            available: false,
          ),
        );
        return Node(
          id: node.id,
          name: node.name,
          region: node.region,
          type: node.type,
          status: result.available ? 'online' : 'offline',
          isActive: node.isActive,
          config: node.config,
          latency: result.latency,
          downloadSpeed: result.downloadSpeed,
        );
      }).toList();

      // 如果启用自动选择，选择最优节点
      Node? bestNode = currentState.selectedNode;
      if (currentState.isAutoSelect) {
        bestNode = _selectBestNode(updatedNodes);
      } else {
        // 更新当前选中节点的测速结果
        if (currentState.selectedNode != null) {
          final updated = updatedNodes.firstWhere(
            (n) => n.id == currentState.selectedNode!.id,
            orElse: () => currentState.selectedNode!,
          );
          bestNode = updated;
        }
      }

      emit(NodeLoaded(
        nodes: updatedNodes,
        selectedNode: bestNode,
        isAutoSelect: currentState.isAutoSelect,
        isTesting: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isTesting: false));
    } finally {
      _isAutoTesting = false;
    }
  }

  /// 选择最优节点
  Node? _selectBestNode(List<Node> nodes) {
    if (nodes.isEmpty) return null;

    final availableNodes = nodes.where((n) => n.latency != null).toList();
    if (availableNodes.isEmpty) return nodes.first;

    availableNodes.sort((a, b) {
      final scoreA = _calculateScore(a);
      final scoreB = _calculateScore(b);
      return scoreB.compareTo(scoreA);
    });

    return availableNodes.first;
  }

  /// 计算节点评分
  double _calculateScore(Node node) {
    double score = 0;

    // 延迟评分（40分）
    if (node.latency != null) {
      if (node.latency! < 50) {
        score += 40;
      } else if (node.latency! < 100) {
        score += 30;
      } else if (node.latency! < 200) {
        score += 20;
      } else if (node.latency! < 500) {
        score += 10;
      }
    }

    // 速度评分（60分）
    if (node.downloadSpeed != null) {
      if (node.downloadSpeed! >= 10) {
        score += 60;
      } else if (node.downloadSpeed! >= 5) {
        score += 45;
      } else if (node.downloadSpeed! >= 1) {
        score += 30;
      } else if (node.downloadSpeed! >= 0.5) {
        score += 15;
      }
    }

    return score;
  }

  /// 手动测速
  Future<void> testAllNodes() async {
    await _autoTest();
  }

  @override
  Future<void> close() {
    _autoTestTimer?.cancel();
    return super.close();
  }
}

