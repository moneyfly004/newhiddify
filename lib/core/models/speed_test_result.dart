import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'server_node.dart';

part 'speed_test_result.g.dart';

/// 测速结果模型
@JsonSerializable()
class SpeedTestResult extends Equatable {
  final ServerNode node;
  final int latency; // 延迟（毫秒）
  final double downloadSpeed; // 下载速度（Mbps）
  final double uploadSpeed; // 上传速度（Mbps）
  final bool availability; // 可用性
  final DateTime testTime;
  final String? error;

  const SpeedTestResult({
    required this.node,
    required this.latency,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.availability,
    required this.testTime,
    this.error,
  });

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) =>
      _$SpeedTestResultFromJson(json);

  Map<String, dynamic> toJson() => _$SpeedTestResultToJson(this);

  @override
  List<Object?> get props => [
        node,
        latency,
        downloadSpeed,
        uploadSpeed,
        availability,
        testTime,
        error,
      ];
}

