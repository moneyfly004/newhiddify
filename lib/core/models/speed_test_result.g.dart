// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speed_test_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpeedTestResult _$SpeedTestResultFromJson(Map<String, dynamic> json) =>
    SpeedTestResult(
      node: ServerNode.fromJson(json['node'] as Map<String, dynamic>),
      latency: (json['latency'] as num).toInt(),
      downloadSpeed: (json['downloadSpeed'] as num).toDouble(),
      uploadSpeed: (json['uploadSpeed'] as num).toDouble(),
      availability: json['availability'] as bool,
      testTime: DateTime.parse(json['testTime'] as String),
      error: json['error'] as String?,
    );

Map<String, dynamic> _$SpeedTestResultToJson(SpeedTestResult instance) =>
    <String, dynamic>{
      'node': instance.node,
      'latency': instance.latency,
      'downloadSpeed': instance.downloadSpeed,
      'uploadSpeed': instance.uploadSpeed,
      'availability': instance.availability,
      'testTime': instance.testTime.toIso8601String(),
      'error': instance.error,
    };
