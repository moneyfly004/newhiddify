import '../../../core/models/user.dart';

/// 认证仓库接口
abstract class AuthRepository {
  /// 登录
  Future<User> login(String email, String password);

  /// 注册
  Future<User> register(String email, String password, String username);

  /// 忘记密码（发送验证码）
  Future<void> forgotPassword(String email);

  /// 重置密码（通过验证码）
  Future<void> resetPassword(String email, String verificationCode, String newPassword);

  /// 登出
  Future<void> logout();

  /// 获取当前用户
  Future<User?> getCurrentUser();

  /// 保存用户信息
  Future<void> saveUser(User user);

  /// 清除用户信息
  Future<void> clearUser();
}

