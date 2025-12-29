import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/auth/model/auth_entity.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class AuthRepository {
  TaskEither<AuthFailure, AuthResponse> login(LoginRequest request);
  TaskEither<AuthFailure, AuthResponse> register(RegisterRequest request);
  TaskEither<AuthFailure, Unit> logout();
  TaskEither<AuthFailure, AuthResponse> refreshToken(String refreshToken);
  TaskEither<AuthFailure, Unit> forgotPassword(String email);
  TaskEither<AuthFailure, Unit> resetPassword(ResetPasswordRequest request);
  TaskEither<AuthFailure, UserEntity> getCurrentUser();
}

class AuthRepositoryImpl
    with ExceptionHandler, InfraLogger
    implements AuthRepository {
  AuthRepositoryImpl({
    required this.httpClient,
    required this.baseUrl,
  });

  final DioHttpClient httpClient;
  final String baseUrl;

  String get _apiBase => '$baseUrl/api/v1';

  @override
  TaskEither<AuthFailure, AuthResponse> login(LoginRequest request) {
    return exceptionHandler(
      () async {
        loggy.debug("登录请求: ${request.toJson()}");
        loggy.debug("登录URL: $_apiBase/auth/login");
        
        final response = await httpClient.post<Map<String, dynamic>>(
          '$_apiBase/auth/login',
          data: request.toJson(),
          proxyOnly: false,
        );

        loggy.debug("登录响应状态码: ${response.statusCode}");
        loggy.debug("登录响应数据: ${response.data}");

        if (response.statusCode == 200 && response.data != null) {
          // 后端返回格式: { "success": true, "data": { "access_token": ..., "refresh_token": ..., "user": ... } }
          final data = response.data!['data'] as Map<String, dynamic>?;
          if (data != null) {
            loggy.debug("从data字段解析: $data");
            try {
              final authResponse = AuthResponse.fromJson(data);
              loggy.debug("登录成功，解析到用户: ${authResponse.user.email}");
              return right(authResponse);
            } catch (e, stackTrace) {
              loggy.error("解析AuthResponse失败", e, stackTrace);
              return left(AuthFailure.unexpected(e, stackTrace));
            }
          }
          // 如果没有data字段，尝试直接解析
          loggy.debug("尝试直接解析响应数据");
          try {
            final authResponse = AuthResponse.fromJson(response.data!);
            return right(authResponse);
          } catch (e, stackTrace) {
            loggy.error("直接解析AuthResponse失败", e, stackTrace);
            return left(AuthFailure.unexpected(e, stackTrace));
          }
        } else {
          loggy.warning("登录失败: 状态码=${response.statusCode}, 数据=${response.data}");
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) {
        loggy.warning("login error", error, stackTrace);
        if (error is DioException) {
          loggy.debug("DioException类型: ${error.type}");
          loggy.debug("响应状态码: ${error.response?.statusCode}");
          loggy.debug("响应数据: ${error.response?.data}");
          
          if (error.response?.statusCode == 401) {
            return const AuthFailure.invalidCredentials();
          } else if (error.response?.statusCode == 403) {
            return const AuthFailure.userDisabled();
          } else if (error.response?.statusCode == 429) {
            return const AuthFailure.deviceLimitExceeded();
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            return const AuthFailure.networkError();
          } else if (error.response?.statusCode == 400) {
            final errorMsg = error.response?.data?['message'] as String?;
            if (errorMsg != null) {
              return AuthFailure.validationError(errorMsg);
            }
          }
        }
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  @override
  TaskEither<AuthFailure, AuthResponse> register(RegisterRequest request) {
    return exceptionHandler(
      () async {
        loggy.debug("注册请求: ${request.toJson()}");
        loggy.debug("注册URL: $_apiBase/auth/register");
        
        final response = await httpClient.post<Map<String, dynamic>>(
          '$_apiBase/auth/register',
          data: request.toJson(),
          proxyOnly: false,
        );

        loggy.debug("注册响应状态码: ${response.statusCode}");
        loggy.debug("注册响应数据: ${response.data}");

        if (response.statusCode == 201 || response.statusCode == 200) {
          // 注册成功后需要登录
          loggy.debug("注册成功，开始登录");
          return login(LoginRequest(
            email: request.email,
            password: request.password,
            deviceId: request.deviceId,
            deviceName: request.deviceName,
          )).run();
        } else {
          final errorMsg = response.data?['message'] as String?;
          loggy.warning("注册失败: $errorMsg");
          if (errorMsg != null) {
            return left(AuthFailure.validationError(errorMsg));
          }
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) {
        loggy.warning("register error", error, stackTrace);
        if (error is DioException) {
          loggy.debug("DioException类型: ${error.type}");
          loggy.debug("响应状态码: ${error.response?.statusCode}");
          loggy.debug("响应数据: ${error.response?.data}");
          
          if (error.response?.statusCode == 400) {
            final errorMsg = error.response?.data?['message'] as String?;
            if (errorMsg != null) {
              return AuthFailure.validationError(errorMsg);
            }
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            return const AuthFailure.networkError();
          }
        }
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  @override
  TaskEither<AuthFailure, Unit> logout() {
    return exceptionHandler(
      () async {
        await httpClient.post(
          '$_apiBase/auth/logout',
          proxyOnly: false,
        );
        return right(unit);
      },
      (error, stackTrace) => const AuthFailure.unexpected(),
    );
  }

  @override
  TaskEither<AuthFailure, AuthResponse> refreshToken(String refreshToken) {
    return exceptionHandler(
      () async {
        final response = await httpClient.post<Map<String, dynamic>>(
          '$_apiBase/auth/refresh',
          data: {'refresh_token': refreshToken},
          proxyOnly: false,
        );

        if (response.statusCode == 200 && response.data != null) {
          // 后端返回格式: { "data": { "access_token": ..., "refresh_token": ..., "user": ... } }
          final data = response.data!['data'] as Map<String, dynamic>?;
          if (data != null) {
            final authResponse = AuthResponse.fromJson(data);
            return right(authResponse);
          }
          // 如果没有data字段，尝试直接解析
          final authResponse = AuthResponse.fromJson(response.data!);
          return right(authResponse);
        } else {
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) => const AuthFailure.unexpected(),
    );
  }

  @override
  TaskEither<AuthFailure, Unit> forgotPassword(String email) {
    return exceptionHandler(
      () async {
        loggy.debug("忘记密码请求: email=$email");
        loggy.debug("忘记密码URL: $_apiBase/auth/forgot-password");
        
        final response = await httpClient.post<Map<String, dynamic>>(
          '$_apiBase/auth/forgot-password',
          data: {'email': email},
          proxyOnly: false,
        );

        loggy.debug("忘记密码响应状态码: ${response.statusCode}");
        loggy.debug("忘记密码响应数据: ${response.data}");

        if (response.statusCode == 200) {
          return right(unit);
        } else {
          final errorMsg = response.data?['message'] as String?;
          if (errorMsg != null) {
            return left(AuthFailure.validationError(errorMsg));
          }
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) {
        loggy.warning("forgotPassword error", error, stackTrace);
        if (error is DioException) {
          loggy.debug("DioException类型: ${error.type}");
          loggy.debug("响应状态码: ${error.response?.statusCode}");
          loggy.debug("响应数据: ${error.response?.data}");
          
          if (error.response?.statusCode == 400) {
            final errorMsg = error.response?.data?['message'] as String?;
            if (errorMsg != null) {
              return AuthFailure.validationError(errorMsg);
            }
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            return const AuthFailure.networkError();
          }
        }
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  @override
  TaskEither<AuthFailure, Unit> resetPassword(ResetPasswordRequest request) {
    return exceptionHandler(
      () async {
        loggy.debug("重置密码请求: ${request.toJson()}");
        loggy.debug("重置密码URL: $_apiBase/auth/reset-password");
        
        final response = await httpClient.post<Map<String, dynamic>>(
          '$_apiBase/auth/reset-password',
          data: request.toJson(),
          proxyOnly: false,
        );

        loggy.debug("重置密码响应状态码: ${response.statusCode}");
        loggy.debug("重置密码响应数据: ${response.data}");

        if (response.statusCode == 200) {
          return right(unit);
        } else {
          final errorMsg = response.data?['message'] as String?;
          if (errorMsg != null) {
            return left(AuthFailure.validationError(errorMsg));
          }
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) {
        loggy.warning("resetPassword error", error, stackTrace);
        if (error is DioException) {
          loggy.debug("DioException类型: ${error.type}");
          loggy.debug("响应状态码: ${error.response?.statusCode}");
          loggy.debug("响应数据: ${error.response?.data}");
          
          if (error.response?.statusCode == 400) {
            final errorMsg = error.response?.data?['message'] as String?;
            if (errorMsg != null) {
              return AuthFailure.validationError(errorMsg);
            }
          } else if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            return const AuthFailure.networkError();
          }
        }
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  @override
  TaskEither<AuthFailure, UserEntity> getCurrentUser() {
    return exceptionHandler(
      () async {
        final response = await httpClient.get<Map<String, dynamic>>(
          '$_apiBase/users/me',
          proxyOnly: false,
        );

        if (response.statusCode == 200 && response.data != null) {
          // 后端返回格式: { "data": { ...user info... } }
          final data = response.data!['data'] as Map<String, dynamic>?;
          if (data != null) {
            final user = UserEntity.fromJson(data);
            return right(user);
          }
          // 如果没有data字段，尝试直接解析
          final user = UserEntity.fromJson(response.data!);
          return right(user);
        } else {
          return left(const AuthFailure.unexpected());
        }
      },
      (error, stackTrace) => const AuthFailure.unexpected(),
    );
  }
}

