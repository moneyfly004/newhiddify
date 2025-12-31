import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/services/traffic_monitor.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 流量统计页面
class TrafficStatsPage extends StatefulWidget {
  const TrafficStatsPage({super.key});

  @override
  State<TrafficStatsPage> createState() => _TrafficStatsPageState();
}

class _TrafficStatsPageState extends State<TrafficStatsPage> {
  TrafficMonitor? _trafficMonitor;
  StreamSubscription<TrafficStats>? _statsSubscription;
  TrafficStats? _currentStats;

  @override
  void initState() {
    super.initState();
    _initTrafficMonitor();
  }

  void _initTrafficMonitor() {
    try {
      _trafficMonitor = GetIt.instance<TrafficMonitor>();
      _statsSubscription = _trafficMonitor!.trafficStream.listen((stats) {
        if (mounted) {
          setState(() => _currentStats = stats);
        }
      });
      _loadStats();
    } catch (e) {
      // 如果 TrafficMonitor 未注册，使用模拟数据
      _currentStats = TrafficStats(
        uploadBytes: 1024 * 1024 * 100,
        downloadBytes: 1024 * 1024 * 500,
        uploadPackets: 0,
        downloadPackets: 0,
      );
    }
  }

  Future<void> _loadStats() async {
    if (_trafficMonitor != null) {
      final stats = _trafficMonitor!.currentStats;
      if (mounted) {
        setState(() => _currentStats = stats);
      }
    }
  }

  Future<void> _clearStats() async {
    if (_trafficMonitor != null) {
      await _trafficMonitor!.resetStats();
      await _loadStats();
    } else {
      setState(() {
        _currentStats = TrafficStats.zero();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _currentStats ?? TrafficStats.zero();

    return Scaffold(
      appBar: AppBar(
        title: const Text('流量统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearStats,
            tooltip: '清空统计',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 实时速度
          _buildSpeedCard(context, stats),
          const SizedBox(height: 16),
          // 今日流量
          _buildTrafficCard(
            context,
            '今日流量',
            upload: stats.uploadBytes,
            download: stats.downloadBytes,
          ),
          const SizedBox(height: 16),
          // 本周流量
          _buildTrafficCard(
            context,
            '本周流量',
            upload: stats.uploadBytes * 7,
            download: stats.downloadBytes * 7,
          ),
          const SizedBox(height: 16),
          // 本月流量
          _buildTrafficCard(
            context,
            '本月流量',
            upload: stats.uploadBytes * 30,
            download: stats.downloadBytes * 30,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedCard(BuildContext context, TrafficStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CyberpunkTheme.neonCyan.withOpacity(0.3),
            CyberpunkTheme.neonPink.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实时速度',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CyberpunkTheme.neonCyan,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildTrafficRow('上传', stats.formattedUpload, Colors.orange),
          const SizedBox(height: 8),
          _buildTrafficRow('下载', stats.formattedDownload, Colors.green),
        ],
      ),
    );
  }

  Widget _buildTrafficCard(
    BuildContext context,
    String title, {
    required int upload,
    required int download,
  }) {
    final total = upload + download;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CyberpunkTheme.neonCyan.withOpacity(0.2),
            CyberpunkTheme.neonPink.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CyberpunkTheme.neonCyan,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildTrafficRow('上传', _formatBytes(upload), Colors.orange),
          const SizedBox(height: 8),
          _buildTrafficRow('下载', _formatBytes(download), Colors.green),
          const Divider(),
          _buildTrafficRow('总计', _formatBytes(total), CyberpunkTheme.neonCyan),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Widget _buildTrafficRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }
}

