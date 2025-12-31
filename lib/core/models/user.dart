import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// 用户模型
@JsonSerializable(explicitToJson: true)
class User extends Equatable {
  final String id;
  final String email;
  final String username;
  final String? avatar;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const User({
    required this.id,
    required this.email,
    required this.username,
    this.avatar,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // 处理后台返回的字段名（下划线转驼峰）和类型转换
    // 注意：登录接口返回的 user 对象可能只包含 id, username, email, is_admin
    final idValue = json['id'];
    final id = idValue is String ? idValue : idValue.toString();
    
    // 处理 email 字段（确保是 String）
    final emailValue = json['email'];
    final email = emailValue is String ? emailValue : (emailValue?.toString() ?? '');
    
    // 处理 username 字段（确保是 String）
    final usernameValue = json['username'];
    final username = usernameValue is String ? usernameValue : (usernameValue?.toString() ?? '');
    
    // 处理 avatar 字段（可能是 String 或 null，也可能是 Map，也可能不存在）
    String? avatar;
    if (json.containsKey('avatar')) {
      final avatarValue = json['avatar'];
      if (avatarValue == null) {
        avatar = null;
      } else if (avatarValue is String) {
        avatar = avatarValue;
      } else if (avatarValue is Map) {
        // 如果 avatar 是 Map，尝试提取 URL 字段
        avatar = avatarValue['url'] as String? ?? avatarValue['avatar_url'] as String?;
      } else {
        avatar = avatarValue.toString();
      }
    } else {
      avatar = null;
    }
    
    // 处理 created_at -> createdAt（可能不存在，使用默认值）
    DateTime createdAt = DateTime.now();
    if (json.containsKey('created_at') || json.containsKey('createdAt')) {
      final createdAtValue = json['created_at'] ?? json['createdAt'];
      if (createdAtValue != null) {
        if (createdAtValue is String) {
          try {
            createdAt = DateTime.parse(createdAtValue);
          } catch (e) {
            // 解析失败，使用默认值
          }
        } else if (createdAtValue is DateTime) {
          createdAt = createdAtValue;
        }
      }
    }
    
    // 处理 last_login -> lastLoginAt（可能不存在，使用 null）
    DateTime? lastLoginAt;
    if (json.containsKey('last_login') || json.containsKey('lastLoginAt')) {
      final lastLoginValue = json['last_login'] ?? json['lastLoginAt'];
      if (lastLoginValue != null) {
        if (lastLoginValue is String) {
          try {
            lastLoginAt = DateTime.parse(lastLoginValue);
          } catch (e) {
            // 解析失败，使用 null
            lastLoginAt = null;
          }
        } else if (lastLoginValue is DateTime) {
          lastLoginAt = lastLoginValue;
        } else {
          lastLoginAt = null;
        }
      } else {
        lastLoginAt = null;
      }
    } else {
      lastLoginAt = null;
    }
    
    return User(
      id: id,
      email: email,
      username: username,
      avatar: avatar,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => [
        id,
        email,
        username,
        avatar,
        createdAt,
        lastLoginAt,
      ];
}

