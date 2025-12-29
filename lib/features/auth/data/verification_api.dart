import 'package:dio/dio.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class VerificationApi with InfraLogger {
  VerificationApi({
    required this.httpClient,
    required this.baseUrl,
  });

  final DioHttpClient httpClient;
  final String baseUrl;

  String get _apiBase => '$baseUrl/api/v1';

  /// 发送验证码
  /// [email] 邮箱地址
  /// [type] 验证码类型: "email"
  /// 返回: (success: bool, message: String?)
  Future<({bool success, String? message})> sendVerificationCode({
    required String email,
    String type = 'email',
  }) async {
    try {
      loggy.debug("发送验证码请求: email=$email, type=$type");
      loggy.debug("发送验证码URL: $_apiBase/auth/verification/send");
      
      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/auth/verification/send',
        data: {
          'email': email,
          'type': type,
        },
        proxyOnly: false,
      );

      loggy.debug("发送验证码响应状态码: ${response.statusCode}");
      loggy.debug("发送验证码响应数据: ${response.data}");

      if (response.statusCode == 200) {
        final message = response.data?['message'] as String?;
        return (success: true, message: message ?? '验证码已发送');
      } else {
        final errorMsg = response.data?['message'] as String?;
        return (success: false, message: errorMsg ?? '发送验证码失败');
      }
    } on DioException catch (e, stackTrace) {
      loggy.warning("发送验证码失败 (DioException)", e, stackTrace);
      loggy.debug("DioException类型: ${e.type}");
      loggy.debug("响应状态码: ${e.response?.statusCode}");
      loggy.debug("响应数据: ${e.response?.data}");
      
      String errorMessage = '发送验证码失败';
      if (e.response != null) {
        final errorMsg = e.response?.data?['message'] as String?;
        if (errorMsg != null) {
          errorMessage = errorMsg;
        } else if (e.response?.statusCode == 400) {
          errorMessage = '请求参数错误';
        } else if (e.response?.statusCode == 403) {
          errorMessage = '注册功能已禁用，请联系管理员';
        } else if (e.response?.statusCode == 429) {
          errorMessage = '请求过于频繁，请稍后再试';
        } else if (e.response?.statusCode == 500) {
          errorMessage = '服务器错误，请稍后重试';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = '连接超时，请检查网络';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = '无法连接到服务器，请检查网络';
      }
      
      return (success: false, message: errorMessage);
    } catch (e, stackTrace) {
      loggy.warning("发送验证码失败 (其他错误)", e, stackTrace);
      return (success: false, message: '发送验证码失败: ${e.toString()}');
    }
  }

  /// 验证验证码
  /// 返回: (success: bool, message: String?)
  Future<({bool success, String? message})> verifyCode({
    required String email,
    required String code,
    String type = 'email',
  }) async {
    try {
      loggy.debug("验证验证码请求: email=$email, code=$code, type=$type");
      loggy.debug("验证验证码URL: $_apiBase/auth/verification/verify");
      
      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/auth/verification/verify',
        data: {
          'email': email,
          'code': code,
          'type': type,
        },
        proxyOnly: false,
      );

      loggy.debug("验证验证码响应状态码: ${response.statusCode}");
      loggy.debug("验证验证码响应数据: ${response.data}");

      if (response.statusCode == 200) {
        final message = response.data?['message'] as String?;
        return (success: true, message: message ?? '验证成功');
      } else {
        final errorMsg = response.data?['message'] as String?;
        return (success: false, message: errorMsg ?? '验证失败');
      }
    } on DioException catch (e, stackTrace) {
      loggy.warning("验证验证码失败 (DioException)", e, stackTrace);
      loggy.debug("DioException类型: ${e.type}");
      loggy.debug("响应状态码: ${e.response?.statusCode}");
      loggy.debug("响应数据: ${e.response?.data}");
      
      String errorMessage = '验证失败';
      if (e.response != null) {
        final errorMsg = e.response?.data?['message'] as String?;
        if (errorMsg != null) {
          errorMessage = errorMsg;
        } else if (e.response?.statusCode == 400) {
          errorMessage = '验证码错误或已使用';
        } else if (e.response?.statusCode == 429) {
          errorMessage = '验证尝试次数过多，请稍后再试';
        }
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = '连接超时，请检查网络';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = '无法连接到服务器，请检查网络';
      }
      
      return (success: false, message: errorMessage);
    } catch (e, stackTrace) {
      loggy.warning("验证验证码失败 (其他错误)", e, stackTrace);
      return (success: false, message: '验证失败: ${e.toString()}');
    }
  }
}

