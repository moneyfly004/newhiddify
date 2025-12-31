import 'package:flutter/foundation.dart';
import '../../../core/models/user.dart';

/// 认证响应
class AuthResponse {
  final String token;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('[AuthResponse] 开始解析 JSON');
      
      // 处理后台返回的包装格式：可能直接是 data 字段，也可能是包装在 ResponseBase 中
      Map<String, dynamic> data = json;
      if (json.containsKey('data') && json['data'] != null) {
        data = json['data'] as Map<String, dynamic>;
        debugPrint('[AuthResponse] 提取 data 字段');
      }
      
      // 安全地获取 token 字段
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;
      
      debugPrint('[AuthResponse] access_token 存在: ${accessToken != null && accessToken.isNotEmpty}');
      debugPrint('[AuthResponse] refresh_token 存在: ${refreshToken != null && refreshToken.isNotEmpty}');
      
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('响应中缺少 access_token 字段或为空');
      }
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('响应中缺少 refresh_token 字段或为空');
      }
      
      // 安全地获取 user 字段
      final userData = data['user'];
      if (userData == null) {
        debugPrint('[AuthResponse] 错误: user 字段为 null');
        throw Exception('响应中缺少 user 字段');
      }
      
      debugPrint('[AuthResponse] user 数据类型: ${userData.runtimeType}');
      
      // 确保 userData 是 Map 类型
      Map<String, dynamic> userMap;
      if (userData is Map) {
        userMap = Map<String, dynamic>.from(userData);
      } else {
        debugPrint('[AuthResponse] 错误: user 字段类型错误: ${userData.runtimeType}');
        throw Exception('user 字段格式错误: 期望 Map，实际为 ${userData.runtimeType}');
      }
      
      debugPrint('[AuthResponse] 开始解析 User 对象');
      final user = User.fromJson(userMap);
      debugPrint('[AuthResponse] User 解析成功: ${user.id}, ${user.email}');
      
      return AuthResponse(
        token: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    } catch (e, stackTrace) {
      debugPrint('[AuthResponse] 解析失败: $e');
      debugPrint('[AuthResponse] 堆栈: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': token,
      'refresh_token': refreshToken,
      'user': user.toJson(),
    };
  }
}

