import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'server_node.g.dart';

/// 服务器节点模型
@JsonSerializable()
class ServerNode extends Equatable {
  final String id;
  final String name;
  final String type; // vmess, vless, trojan, shadowsocks, etc.
  final String address;
  final int port;
  final String? password;
  final Map<String, dynamic>? config;
  final String? group;
  final bool isActive;
  final DateTime? lastTested;
  
  const ServerNode({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.port,
    this.password,
    this.config,
    this.group,
    this.isActive = false,
    this.lastTested,
  });

  factory ServerNode.fromJson(Map<String, dynamic> json) =>
      _$ServerNodeFromJson(json);

  Map<String, dynamic> toJson() => _$ServerNodeToJson(this);

  ServerNode copyWith({
    String? id,
    String? name,
    String? type,
    String? address,
    int? port,
    String? password,
    Map<String, dynamic>? config,
    String? group,
    bool? isActive,
    DateTime? lastTested,
  }) {
    return ServerNode(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      port: port ?? this.port,
      password: password ?? this.password,
      config: config ?? this.config,
      group: group ?? this.group,
      isActive: isActive ?? this.isActive,
      lastTested: lastTested ?? this.lastTested,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        address,
        port,
        password,
        config,
        group,
        isActive,
        lastTested,
      ];
}

