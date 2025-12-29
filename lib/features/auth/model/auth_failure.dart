import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';

part 'auth_failure.freezed.dart';

@freezed
class AuthFailure with _$AuthFailure implements Failure {
  const AuthFailure._();
  const factory AuthFailure.unexpected([Object? error, StackTrace? stackTrace]) =
      _Unexpected;
  const factory AuthFailure.invalidCredentials() = _InvalidCredentials;
  const factory AuthFailure.userDisabled() = _UserDisabled;
  const factory AuthFailure.deviceLimitExceeded() = _DeviceLimitExceeded;
  const factory AuthFailure.networkError([String? message]) = _NetworkError;
  const factory AuthFailure.validationError(String message) = _ValidationError;

  @override
  ({String? message, String type}) present(Translations t) {
    return switch (this) {
      _Unexpected() => (message: t.failure.unexpected, type: 'unexpected'),
      _InvalidCredentials() => (message: "邮箱或密码错误", type: 'invalid_credentials'),
      _UserDisabled() => (message: "账号已禁用", type: 'user_disabled'),
      _DeviceLimitExceeded() => (message: "设备数量已达上限", type: 'device_limit_exceeded'),
      _NetworkError(:final message) => (message: message ?? t.failure.unexpected, type: 'network'),
      _ValidationError(:final message) => (message: message, type: 'validation'),
      _ => (message: t.failure.unexpected, type: 'unexpected'),
    };
  }
}

