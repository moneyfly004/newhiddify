import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/user.dart';
import '../../../data/remote/api_client.dart';
import 'auth_repository.dart';
import '../models/auth_response.dart';

/// 认证仓库实现
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  AuthRepositoryImpl(this._apiClient, this._prefs);

  @override
  Future<User> login(String email, String password) async {
    try {
      debugPrint('[AuthRepository] 开始登录请求: email=$email');
      debugPrint('[AuthRepository] API URL: https://dy.moneyfly.top/api/v1/auth/login');
      
      final response = await _apiClient.login({
        'email': email,
        'password': password,
      });
      
      debugPrint('[AuthRepository] 登录响应收到');
      debugPrint('[AuthRepository] Token长度: ${response.token.length}');
      debugPrint('[AuthRepository] User ID: ${response.user.id}');
      debugPrint('[AuthRepository] User Email: ${response.user.email}');

      // 验证 token 不为空
      if (response.token.isEmpty) {
        throw Exception('登录失败：服务器未返回有效的访问令牌');
      }

      // 保存 Token 和用户信息
      await _prefs.setString('auth_token', response.token);
      await _prefs.setString('refresh_token', response.refreshToken);
      await _prefs.setString('user', jsonEncode(response.user.toJson()));
      debugPrint('[AuthRepository] 用户信息已保存');

      return response.user;
    } on DioException catch (e) {
      debugPrint('[AuthRepository] DioException: ${e.type}, message=${e.message}');
      if (e.response != null) {
        debugPrint('[AuthRepository] 响应状态码: ${e.response?.statusCode}');
        debugPrint('[AuthRepository] 响应数据: ${e.response?.data}');
        // 处理 ResponseBase 包装的错误响应
        final responseData = e.response?.data;
        String message = '登录失败，请检查邮箱和密码';
        if (responseData is Map) {
          // 检查是否是 ResponseBase 格式
          if (responseData.containsKey('message')) {
            message = responseData['message'] as String? ?? message;
          } else if (responseData.containsKey('detail')) {
            message = responseData['detail'] as String? ?? message;
          } else if (responseData.containsKey('error')) {
            message = responseData['error'] as String? ?? message;
          }
        }
        throw Exception(message);
      }
      debugPrint('[AuthRepository] 网络错误: ${e.message}');
      // 处理网络错误
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('连接超时，请检查网络连接');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络设置');
      }
      throw Exception('网络错误，请检查网络连接: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] 未知错误: $e');
      debugPrint('[AuthRepository] 堆栈: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<User> register(
    String email,
    String password,
    String username,
  ) async {
    try {
      debugPrint('[AuthRepository] 开始注册请求: email=$email, username=$username');
      // 注册 API 不返回 token，需要注册后自动登录
      await _apiClient.register({
        'email': email,
        'password': password,
        'username': username,
      });
      debugPrint('[AuthRepository] 注册成功，开始自动登录');

      // 注册成功后自动登录获取 token
      final loginResponse = await _apiClient.login({
        'email': email,
        'password': password,
      });
      debugPrint('[AuthRepository] 自动登录成功');

      // 保存 Token 和用户信息
      await _prefs.setString('auth_token', loginResponse.token);
      await _prefs.setString('refresh_token', loginResponse.refreshToken);
      await _prefs.setString('user', jsonEncode(loginResponse.user.toJson()));

      return loginResponse.user;
    } on DioException catch (e) {
      debugPrint('[AuthRepository] 注册失败: ${e.type}, message=${e.message}');
      if (e.response != null) {
        debugPrint('[AuthRepository] 响应状态码: ${e.response?.statusCode}');
        debugPrint('[AuthRepository] 响应数据: ${e.response?.data}');
        // 处理 ResponseBase 包装的错误
        final responseData = e.response?.data;
        String message = '注册失败，请检查输入信息';
        if (responseData is Map) {
          message = responseData['message'] as String? ??
              responseData['detail'] as String? ??
              message;
        }
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] 注册未知错误: $e');
      debugPrint('[AuthRepository] 堆栈: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      debugPrint('[AuthRepository] 发送忘记密码请求: email=$email');
      await _apiClient.forgotPassword({
        'email': email,
      });
      debugPrint('[AuthRepository] 验证码已发送');
    } on DioException catch (e) {
      debugPrint('[AuthRepository] 忘记密码失败: ${e.type}, message=${e.message}');
      if (e.response != null) {
        debugPrint('[AuthRepository] 响应状态码: ${e.response?.statusCode}');
        debugPrint('[AuthRepository] 响应数据: ${e.response?.data}');
        // 处理 ResponseBase 包装的错误响应
        final responseData = e.response?.data;
        String message = '发送验证码失败';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            message = responseData['message'] as String? ?? message;
          } else if (responseData.containsKey('detail')) {
            message = responseData['detail'] as String? ?? message;
          } else if (responseData.containsKey('error')) {
            message = responseData['error'] as String? ?? message;
          }
        }
        throw Exception(message);
      }
      // 处理网络错误
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('连接超时，请检查网络连接');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络设置');
      }
      throw Exception('网络错误，请检查网络连接: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] 忘记密码未知错误: $e');
      debugPrint('[AuthRepository] 堆栈: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email, String verificationCode, String newPassword) async {
    try {
      debugPrint('[AuthRepository] 重置密码请求: email=$email');
      await _apiClient.resetPassword({
        'email': email,
        'verification_code': verificationCode,
        'new_password': newPassword,
      });
      debugPrint('[AuthRepository] 密码重置成功');
    } on DioException catch (e) {
      debugPrint('[AuthRepository] 重置密码失败: ${e.type}, message=${e.message}');
      if (e.response != null) {
        debugPrint('[AuthRepository] 响应状态码: ${e.response?.statusCode}');
        debugPrint('[AuthRepository] 响应数据: ${e.response?.data}');
        // 处理 ResponseBase 包装的错误响应
        final responseData = e.response?.data;
        String message = '重置密码失败';
        if (responseData is Map) {
          if (responseData.containsKey('message')) {
            message = responseData['message'] as String? ?? message;
          } else if (responseData.containsKey('detail')) {
            message = responseData['detail'] as String? ?? message;
          } else if (responseData.containsKey('error')) {
            message = responseData['error'] as String? ?? message;
          }
        }
        throw Exception(message);
      }
      // 处理网络错误
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('连接超时，请检查网络连接');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络设置');
      }
      throw Exception('网络错误，请检查网络连接: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[AuthRepository] 重置密码未知错误: $e');
      debugPrint('[AuthRepository] 堆栈: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (e) {
      // 即使 API 调用失败，也清除本地数据
    } finally {
      await clearUser();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      // 先尝试从本地获取
      final userJson = _prefs.getString('user');
      if (userJson != null) {
        try {
          return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        } catch (e) {
          // JSON 解析失败，清除无效数据
          await _prefs.remove('user');
        }
      }

      // 如果本地没有，从服务器获取
      final user = await _apiClient.getCurrentUser();
      await saveUser(user);
      return user;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveUser(User user) async {
    await _prefs.setString('user', jsonEncode(user.toJson()));
  }

  @override
  Future<void> clearUser() async {
    await _prefs.remove('auth_token');
    await _prefs.remove('refresh_token');
    await _prefs.remove('user');
  }
}
