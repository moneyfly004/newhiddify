import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// 流量监控器
class TrafficMonitor {
  static const MethodChannel _channel = MethodChannel('com.proxyapp/traffic');
  
  final _trafficController = StreamController<TrafficStats>.broadcast();
  Timer? _monitorTimer;
  TrafficStats _currentStats = TrafficStats.zero();

  TrafficMonitor() {
    startMonitoring();
  }

  /// 流量统计流
  Stream<TrafficStats> get trafficStream => _trafficController.stream;

  /// 当前统计
  TrafficStats get currentStats => _currentStats;

  /// 启动监控
  void startMonitoring({Duration interval = const Duration(seconds: 1)}) {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (timer) {
      _updateTraffic();
    });
    Logger.info('流量监控已启动');
  }

  /// 停止监控
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    Logger.info('流量监控已停止');
  }

  /// 更新流量统计
  Future<void> _updateTraffic() async {
    try {
      final stats = await _channel.invokeMethod<Map<Object?, Object?>>('get_traffic_stats');
      if (stats != null) {
        _currentStats = TrafficStats.fromMap(Map<String, dynamic>.from(stats));
        _trafficController.add(_currentStats);
      }
    } catch (e) {
      Logger.error('获取流量统计失败', e);
    }
  }

  /// 重置统计
  Future<void> resetStats() async {
    try {
      await _channel.invokeMethod('reset_traffic_stats');
      _currentStats = TrafficStats.zero();
      _trafficController.add(_currentStats);
      Logger.info('流量统计已重置');
    } catch (e) {
      Logger.error('重置流量统计失败', e);
    }
  }

  /// 释放资源
  void dispose() {
    stopMonitoring();
    _trafficController.close();
  }
}

/// 流量统计
class TrafficStats {
  final int uploadBytes;
  final int downloadBytes;
  final int uploadPackets;
  final int downloadPackets;
  final DateTime timestamp;

  TrafficStats({
    required this.uploadBytes,
    required this.downloadBytes,
    required this.uploadPackets,
    required this.downloadPackets,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 零值
  factory TrafficStats.zero() {
    return TrafficStats(
      uploadBytes: 0,
      downloadBytes: 0,
      uploadPackets: 0,
      downloadPackets: 0,
    );
  }

  /// 从 Map 创建
  factory TrafficStats.fromMap(Map<String, dynamic> map) {
    return TrafficStats(
      uploadBytes: map['upload_bytes'] as int? ?? 0,
      downloadBytes: map['download_bytes'] as int? ?? 0,
      uploadPackets: map['upload_packets'] as int? ?? 0,
      downloadPackets: map['download_packets'] as int? ?? 0,
    );
  }

  /// 总流量（字节）
  int get totalBytes => uploadBytes + downloadBytes;

  /// 总流量（MB）
  double get totalMB => totalBytes / (1024 * 1024);

  /// 上传速度（MB/s）
  double get uploadSpeedMB => uploadBytes / (1024 * 1024);

  /// 下载速度（MB/s）
  double get downloadSpeedMB => downloadBytes / (1024 * 1024);

  /// 格式化上传流量
  String get formattedUpload {
    if (uploadBytes < 1024) return '$uploadBytes B';
    if (uploadBytes < 1024 * 1024) return '${(uploadBytes / 1024).toStringAsFixed(2)} KB';
    if (uploadBytes < 1024 * 1024 * 1024) return '${(uploadBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(uploadBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 格式化下载流量
  String get formattedDownload {
    if (downloadBytes < 1024) return '$downloadBytes B';
    if (downloadBytes < 1024 * 1024) return '${(downloadBytes / 1024).toStringAsFixed(2)} KB';
    if (downloadBytes < 1024 * 1024 * 1024) return '${(downloadBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(downloadBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 格式化总流量
  String get formattedTotal {
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(2)} KB';
    if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

