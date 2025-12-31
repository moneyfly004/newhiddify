import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/kernel_type.dart';
import '../models/connection_mode.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import 'encryption_service.dart';
import '../utils/logger.dart';

/// 存储服务 - 统一管理本地数据存储
class StorageService {
  static const String _keyUser = 'user';
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyKernelType = 'kernel_type';
  static const String _keyConnectionMode = 'connection_mode';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyAutoTestSpeed = 'auto_test_speed';
  static const String _keyCurrentSubscription = 'current_subscription';
  static const String _keyCurrentNode = 'current_node';
  static const String _keyConnectionState = 'connection_state';
  static const String _keySubscriptions = 'subscriptions_cache';
  static const String _keyNodes = 'nodes_cache';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ==================== 用户相关 ====================

  /// 保存用户信息
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _prefs.setString(_keyUser, jsonEncode(user));
  }

  /// 获取用户信息
  Map<String, dynamic>? getUser() {
    final userStr = _prefs.getString(_keyUser);
    if (userStr == null) return null;
    try {
      return jsonDecode(userStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 清除用户信息
  Future<void> clearUser() async {
    await _prefs.remove(_keyUser);
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyRefreshToken);
  }

  // ==================== Token 相关 ====================

  /// 保存 Token（加密）
  Future<void> saveToken(String token) async {
    final seed = await _getEncryptionSeed();
    final encrypted = EncryptionService.encrypt(token, seed);
    await _prefs.setString(_keyToken, encrypted);
  }

  /// 获取 Token（解密）
  String? getToken() {
    final encrypted = _prefs.getString(_keyToken);
    if (encrypted == null) return null;
    
    try {
      final seed = _getEncryptionSeedSync();
      return EncryptionService.decrypt(encrypted, seed);
    } catch (e) {
      Logger.error('解密 Token 失败', e);
      return null;
    }
  }

  /// 保存刷新 Token（加密）
  Future<void> saveRefreshToken(String refreshToken) async {
    final seed = await _getEncryptionSeed();
    final encrypted = EncryptionService.encrypt(refreshToken, seed);
    await _prefs.setString(_keyRefreshToken, encrypted);
  }

  /// 获取刷新 Token（解密）
  String? getRefreshToken() {
    final encrypted = _prefs.getString(_keyRefreshToken);
    if (encrypted == null) return null;
    
    try {
      final seed = _getEncryptionSeedSync();
      return EncryptionService.decrypt(encrypted, seed);
    } catch (e) {
      Logger.error('解密 RefreshToken 失败', e);
      return null;
    }
  }

  /// 获取加密种子（异步）
  Future<String> _getEncryptionSeed() async {
    final user = getUser();
    if (user != null && user.containsKey('id')) {
      return user['id'].toString();
    }
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.packageName}_${packageInfo.version}';
  }

  /// 获取加密种子（同步）
  String _getEncryptionSeedSync() {
    final user = getUser();
    if (user != null && user.containsKey('id')) {
      return user['id'].toString();
    }
    // 同步版本使用默认值
    return 'proxy_app_default_seed';
  }

  // ==================== 内核设置 ====================

  /// 保存内核类型
  Future<void> saveKernelType(KernelType kernelType) async {
    await _prefs.setString(_keyKernelType, kernelType.name);
  }

  /// 获取内核类型
  KernelType getKernelType() {
    final typeStr = _prefs.getString(_keyKernelType);
    if (typeStr == null) return KernelType.singbox;
    return KernelType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => KernelType.singbox,
    );
  }

  // ==================== 连接模式 ====================

  /// 保存连接模式
  Future<void> saveConnectionMode(ConnectionMode mode) async {
    await _prefs.setString(_keyConnectionMode, mode.name);
  }

  /// 获取连接模式
  ConnectionMode getConnectionMode() {
    final modeStr = _prefs.getString(_keyConnectionMode);
    if (modeStr == null) return ConnectionMode.rules;
    return ConnectionMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => ConnectionMode.rules,
    );
  }

  // ==================== 应用设置 ====================

  /// 保存自动连接设置
  Future<void> saveAutoConnect(bool autoConnect) async {
    await _prefs.setBool(_keyAutoConnect, autoConnect);
  }

  /// 获取自动连接设置
  bool getAutoConnect() {
    return _prefs.getBool(_keyAutoConnect) ?? false;
  }

  /// 保存自动测速设置
  Future<void> saveAutoTestSpeed(bool autoTestSpeed) async {
    await _prefs.setBool(_keyAutoTestSpeed, autoTestSpeed);
  }

  /// 获取自动测速设置
  bool getAutoTestSpeed() {
    return _prefs.getBool(_keyAutoTestSpeed) ?? true;
  }

  // ==================== 连接状态 ====================

  /// 保存当前订阅
  Future<void> saveCurrentSubscription(Subscription subscription) async {
    await _prefs.setString(_keyCurrentSubscription, jsonEncode(subscription.toJson()));
  }

  /// 获取当前订阅
  Subscription? getCurrentSubscription() {
    final subStr = _prefs.getString(_keyCurrentSubscription);
    if (subStr == null) return null;
    try {
      return Subscription.fromJson(jsonDecode(subStr) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// 保存当前节点
  Future<void> saveCurrentNode(Node node) async {
    await _prefs.setString(_keyCurrentNode, jsonEncode(node.toJson()));
  }

  /// 获取当前节点
  Node? getCurrentNode() {
    final nodeStr = _prefs.getString(_keyCurrentNode);
    if (nodeStr == null) return null;
    try {
      return Node.fromJson(jsonDecode(nodeStr) as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// 保存连接状态
  Future<void> saveConnectionState(bool isConnected) async {
    await _prefs.setBool(_keyConnectionState, isConnected);
  }

  /// 获取连接状态
  bool getConnectionState() {
    return _prefs.getBool(_keyConnectionState) ?? false;
  }

  // ==================== 缓存数据 ====================

  /// 保存订阅列表缓存
  Future<void> saveSubscriptionsCache(List<Subscription> subscriptions) async {
    final data = subscriptions.map((s) => s.toJson()).toList();
    await _prefs.setString(_keySubscriptions, jsonEncode(data));
  }

  /// 获取订阅列表缓存
  List<Subscription>? getSubscriptionsCache() {
    final dataStr = _prefs.getString(_keySubscriptions);
    if (dataStr == null) return null;
    try {
      final data = jsonDecode(dataStr) as List;
      return data.map((json) => Subscription.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  /// 保存节点列表缓存
  Future<void> saveNodesCache(List<Node> nodes) async {
    final data = nodes.map((n) => n.toJson()).toList();
    await _prefs.setString(_keyNodes, jsonEncode(data));
  }

  /// 获取节点列表缓存
  List<Node>? getNodesCache() {
    final dataStr = _prefs.getString(_keyNodes);
    if (dataStr == null) return null;
    try {
      final data = jsonDecode(dataStr) as List;
      return data.map((json) => Node.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }

  // ==================== 清理 ====================

  /// 清除所有数据
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  /// 清除缓存数据
  Future<void> clearCache() async {
    await _prefs.remove(_keySubscriptions);
    await _prefs.remove(_keyNodes);
  }
}

