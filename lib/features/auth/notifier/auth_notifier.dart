import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_entity.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/subscription/notifier/auto_subscription_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/device_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

const String _accessTokenKey = 'access_token';
const String _refreshTokenKey = 'refresh_token';
const String _userKey = 'user';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier with ExceptionHandler, InfraLogger {
  @override
  Future<AsyncValue<UserEntity?>> build() async {
    // 从本地存储加载token和用户信息
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final accessToken = prefs.getString(_accessTokenKey);
    final userJson = prefs.getString(_userKey);

    if (accessToken != null && userJson != null) {
      try {
        // 设置HTTP客户端的token
        ref.read(httpClientProvider).setAccessToken(accessToken);

        // 验证token是否有效
        final currentUser = await ref.read(authRepositoryProvider).getCurrentUser().run();

        return currentUser.fold(
          (failure) {
            // Token无效，清除本地存储
            _clearAuthData();
            return const AsyncValue.data(null);
          },
          (user) => AsyncValue.data(user),
        );
      } catch (e) {
        _clearAuthData();
        return const AsyncValue.data(null);
      }
    }

    return const AsyncValue.data(null);
  }

  Future<Either<AuthFailure, Unit>> login(String email, String password) async {
    state = AsyncValue.data(const AsyncValue.loading());

    final deviceId = await DeviceIdHelper.getDeviceId();
    final deviceName = await DeviceIdHelper.getDeviceName();

    final result = await ref
        .read(authRepositoryProvider)
        .login(
          LoginRequest(
            email: email,
            password: password,
            deviceId: deviceId,
            deviceName: deviceName,
          ),
        )
        .run();

    return result.fold(
      (failure) {
        state = AsyncValue.data(AsyncValue.error(failure, StackTrace.current));
        return left(failure);
      },
      (authResponse) async {
        // 保存token和用户信息
        await _saveAuthData(authResponse);

        // 设置HTTP客户端的token
        ref.read(httpClientProvider).setAccessToken(authResponse.accessToken);

        state = AsyncValue.data(AsyncValue.data(authResponse.user));

        // 登录成功后立即加载订阅
        try {
          await ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
        } catch (e) {
          // 静默失败，不影响登录流程
          print('登录后加载订阅失败: $e');
        }

        return right(unit);
      },
    );
  }

  Future<Either<AuthFailure, Unit>> register(
    String username,
    String email,
    String password, {
    String? verificationCode,
    String? inviteCode,
  }) async {
    state = AsyncValue.data(const AsyncValue.loading());

    final deviceId = await DeviceIdHelper.getDeviceId();
    final deviceName = await DeviceIdHelper.getDeviceName();

    final result = await ref
        .read(authRepositoryProvider)
        .register(
          RegisterRequest(
            username: username,
            email: email,
            password: password,
            verificationCode: verificationCode,
            inviteCode: inviteCode,
            deviceId: deviceId,
            deviceName: deviceName,
          ),
        )
        .run();

    return result.fold(
      (failure) {
        state = AsyncValue.data(AsyncValue.error(failure, StackTrace.current));
        return left(failure);
      },
      (authResponse) async {
        // 保存token和用户信息
        await _saveAuthData(authResponse);

        // 设置HTTP客户端的token
        ref.read(httpClientProvider).setAccessToken(authResponse.accessToken);

        state = AsyncValue.data(AsyncValue.data(authResponse.user));

        // 注册成功后立即加载订阅
        try {
          await ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
        } catch (e) {
          // 静默失败，不影响注册流程
          print('注册后加载订阅失败: $e');
        }

        return right(unit);
      },
    );
  }

  Future<Either<AuthFailure, Unit>> logout() async {
    final result = await ref.read(authRepositoryProvider).logout().run();

    return result.fold(
      (failure) async {
        // 即使后端失败，也清除本地数据
        await _clearAuthData();
        state = AsyncValue.data(const AsyncValue.data(null));
        return left(failure);
      },
      (_) async {
        await _clearAuthData();
        state = AsyncValue.data(const AsyncValue.data(null));
        return right(unit);
      },
    );
  }

  Future<void> _saveAuthData(AuthResponse authResponse) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_accessTokenKey, authResponse.accessToken);
    await prefs.setString(_refreshTokenKey, authResponse.refreshToken);
    // 保存用户信息（序列化为JSON字符串）
    await prefs.setString(_userKey, jsonEncode(authResponse.user.toJson()));
  }

  Future<void> _clearAuthData() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    ref.read(httpClientProvider).clearAccessToken();
    await DeviceIdHelper.clearDeviceId();
  }

  bool get isAuthenticated {
    return state.valueOrNull?.valueOrNull != null;
  }

  UserEntity? get currentUser {
    return state.valueOrNull?.valueOrNull;
  }
}
