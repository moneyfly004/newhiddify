// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerNode _$ServerNodeFromJson(Map<String, dynamic> json) => ServerNode(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      address: json['address'] as String,
      port: (json['port'] as num).toInt(),
      password: json['password'] as String?,
      config: json['config'] as Map<String, dynamic>?,
      group: json['group'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      lastTested: json['lastTested'] == null
          ? null
          : DateTime.parse(json['lastTested'] as String),
    );

Map<String, dynamic> _$ServerNodeToJson(ServerNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'address': instance.address,
      'port': instance.port,
      'password': instance.password,
      'config': instance.config,
      'group': instance.group,
      'isActive': instance.isActive,
      'lastTested': instance.lastTested?.toIso8601String(),
    };
