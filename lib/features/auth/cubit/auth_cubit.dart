import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

/// 认证 Cubit
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(const AuthUnauthenticated()) {
    _checkAuthStatus();
  }

  /// 检查认证状态
  Future<void> _checkAuthStatus() async {
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// 登录
  Future<void> login(String email, String password) async {
    try {
      debugPrint('[AuthCubit] 开始登录流程');
      emit(const AuthLoading());
      final user = await _repository.login(email, password);
      debugPrint('[AuthCubit] 登录成功，用户ID: ${user.id}');
      emit(AuthAuthenticated(user));
      
      // 登录成功后，触发订阅自动加载
      // 这将在 HomePage 的 BlocListener 中处理
    } catch (e, stackTrace) {
      debugPrint('[AuthCubit] 登录失败: $e');
      debugPrint('[AuthCubit] 堆栈: $stackTrace');
      emit(AuthError(e.toString()));
    }
  }

  /// 注册
  Future<void> register(
    String email,
    String password,
    String username,
  ) async {
    try {
      emit(const AuthLoading());
      final user = await _repository.register(email, password, username);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// 忘记密码（发送验证码）
  Future<void> forgotPassword(String email) async {
    try {
      emit(const AuthLoading());
      await _repository.forgotPassword(email);
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// 重置密码（通过验证码）
  Future<void> resetPassword(String email, String verificationCode, String newPassword) async {
    try {
      emit(const AuthLoading());
      await _repository.resetPassword(email, verificationCode, newPassword);
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      await _repository.logout();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

