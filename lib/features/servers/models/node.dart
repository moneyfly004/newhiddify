/// 节点模型
class Node {
  final String id;
  final String name;
  final String? region;
  final String type;
  final String status;
  final bool isActive;
  final String? config;
  final int? latency;
  final double? downloadSpeed;

  Node({
    required this.id,
    required this.name,
    this.region,
    required this.type,
    required this.status,
    required this.isActive,
    this.config,
    this.latency,
    this.downloadSpeed,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      region: json['region'] as String?,
      type: json['type'] as String? ?? '',
      status: json['status'] as String? ?? 'offline',
      isActive: json['is_active'] as bool? ?? false,
      config: json['config'] as String?,
      latency: json['latency'] as int?,
      downloadSpeed: (json['download_speed'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'type': type,
      'status': status,
      'is_active': isActive,
      'config': config,
      'latency': latency,
      'download_speed': downloadSpeed,
    };
  }

  /// 是否在线
  bool get isOnline => status == 'online';

  /// 获取延迟显示文本
  String get latencyText {
    if (latency == null) return '-';
    if (latency! < 50) return '${latency}ms (优秀)';
    if (latency! < 100) return '${latency}ms (良好)';
    if (latency! < 200) return '${latency}ms (一般)';
    return '${latency}ms (较慢)';
  }

  /// 获取速度显示文本
  String get speedText {
    if (downloadSpeed == null) return '-';
    if (downloadSpeed! >= 10) {
      return '${downloadSpeed!.toStringAsFixed(2)} MB/s';
    }
    return '${(downloadSpeed! * 1024).toStringAsFixed(0)} KB/s';
  }
}

