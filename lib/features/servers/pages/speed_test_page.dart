import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../ui/theme/cyberpunk_theme.dart';
import '../cubit/node_cubit.dart';
import '../models/node.dart';
import '../../../core/services/speed_test_engine.dart';

/// 测速页面
class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key});

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节点测速'),
      ),
      body: BlocBuilder<NodeCubit, NodeState>(
        builder: (context, state) {
          if (state is NodeLoaded) {
            return Column(
              children: [
                // 测速控制
                _buildTestControls(context, state),
                
                // 测速结果列表
                Expanded(
                  child: _buildTestResults(context, state.nodes),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildTestControls(BuildContext context, NodeLoaded state) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: CyberpunkTheme.neonGradient(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '测速状态',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (state.isTesting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: state.isTesting
                ? null
                : () {
                    context.read<NodeCubit>().testAllNodes();
                  },
            icon: const Icon(Icons.speed),
            label: Text(state.isTesting ? '测速中...' : '开始测速'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults(BuildContext context, List<Node> nodes) {
    if (nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无节点',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    // 按评分排序
    final sortedNodes = List<Node>.from(nodes);
    sortedNodes.sort((a, b) {
      final scoreA = _calculateScore(a);
      final scoreB = _calculateScore(b);
      return scoreB.compareTo(scoreA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedNodes.length,
      itemBuilder: (context, index) {
        final node = sortedNodes[index];
        final score = _calculateScore(node);
        final rank = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CyberpunkTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getRankColor(rank).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // 排名
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getRankColor(rank).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRankColor(rank),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      color: _getRankColor(rank),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // 节点信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            node.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (node.region != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CyberpunkTheme.neonCyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              node.region!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CyberpunkTheme.neonCyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (node.latency != null) ...[
                          Icon(
                            Icons.speed,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            node.latencyText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (node.downloadSpeed != null) ...[
                          Icon(
                            Icons.download,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            node.speedText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // 评分
              Column(
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(score),
                    ),
                  ),
                  Text(
                    '分',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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

  Color _getRankColor(int rank) {
    if (rank == 1) return CyberpunkTheme.neonYellow;
    if (rank == 2) return CyberpunkTheme.neonCyan;
    if (rank == 3) return CyberpunkTheme.neonGreen;
    return CyberpunkTheme.neonPink;
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return CyberpunkTheme.neonGreen;
    if (score >= 60) return CyberpunkTheme.neonCyan;
    if (score >= 40) return CyberpunkTheme.neonYellow;
    return CyberpunkTheme.neonPink;
  }
}
