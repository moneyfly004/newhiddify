import 'package:equatable/equatable.dart';
import '../../../core/models/user.dart';

/// 认证状态基类
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// 未认证状态
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// 认证中状态
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// 已认证状态
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// 认证错误状态
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

