import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../../core/models/user.dart';
import '../../features/auth/models/auth_response.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';

part 'api_client.g.dart';

/// API 基础 URL
const String baseUrl = 'https://dy.moneyfly.top/api/v1';

/// API 客户端
@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // ==================== 认证相关 ====================
  
  /// 登录
  @POST('/auth/login')
  Future<AuthResponse> login(@Body() Map<String, dynamic> body);

  /// 注册
  @POST('/auth/register')
  Future<AuthResponse> register(@Body() Map<String, dynamic> body);

  /// 刷新 Token
  @POST('/auth/refresh')
  Future<AuthResponse> refreshToken(@Body() Map<String, dynamic> body);

  /// 登出
  @POST('/auth/logout')
  Future<void> logout();

  /// 忘记密码（发送验证码）
  @POST('/auth/forgot-password')
  Future<void> forgotPassword(@Body() Map<String, dynamic> body);

  /// 重置密码（通过验证码）
  @POST('/auth/reset-password')
  Future<void> resetPassword(@Body() Map<String, dynamic> body);

  // ==================== 用户相关 ====================
  
  /// 获取当前用户信息
  @GET('/users/me')
  Future<User> getCurrentUser();

  /// 更新用户信息
  @PUT('/users/me')
  Future<User> updateUser(@Body() Map<String, dynamic> body);

  // ==================== 订阅相关 ====================
  
  /// 获取订阅列表
  @GET('/subscriptions')
  @DioResponseType(ResponseType.json)
  Future<Response<dynamic>> getSubscriptions();

  /// 获取订阅详情
  @GET('/subscriptions/:id')
  Future<Subscription> getSubscription(@Path('id') String id);

  /// 获取 Clash 订阅配置
  @GET('/subscriptions/clash/:url')
  Future<String> getClashConfig(
    @Path('url') String url,
    @Query('t') String timestamp,
  );

  /// 获取通用订阅配置
  @GET('/subscriptions/universal/:url')
  Future<String> getUniversalConfig(
    @Path('url') String url,
    @Query('t') String timestamp,
  );

  // ==================== 节点相关 ====================
  
  /// 获取节点列表
  @GET('/nodes')
  Future<Response<dynamic>> getNodes();

  /// 获取节点详情
  @GET('/nodes/:id')
  Future<Node> getNode(@Path('id') String id);

  /// 测试单个节点
  @POST('/nodes/:id/test')
  Future<NodeTestResult> testNode(@Path('id') String id);

  /// 批量测试节点
  @POST('/nodes/batch-test')
  Future<List<NodeTestResult>> batchTestNodes(@Body() Map<String, dynamic> body);

  // ==================== 设备相关 ====================
  
  /// 获取设备列表
  @GET('/devices')
  Future<List<Device>> getDevices();

  /// 删除设备
  @DELETE('/devices/:id')
  Future<void> deleteDevice(@Path('id') String id);
}

/// 节点测试结果
class NodeTestResult {
  final String nodeId;
  final int? latency;
  final double? downloadSpeed;
  final bool available;

  NodeTestResult({
    required this.nodeId,
    this.latency,
    this.downloadSpeed,
    required this.available,
  });

  factory NodeTestResult.fromJson(Map<String, dynamic> json) {
    return NodeTestResult(
      nodeId: json['node_id'] as String,
      latency: json['latency'] as int?,
      downloadSpeed: (json['download_speed'] as num?)?.toDouble(),
      available: json['available'] as bool? ?? false,
    );
  }
}

/// 设备模型
class Device {
  final String id;
  final String? deviceName;
  final String? deviceType;
  final String? ipAddress;
  final DateTime lastAccess;
  final bool isActive;

  Device({
    required this.id,
    this.deviceName,
    this.deviceType,
    this.ipAddress,
    required this.lastAccess,
    required this.isActive,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'].toString(),
      deviceName: json['device_name'] as String?,
      deviceType: json['device_type'] as String?,
      ipAddress: json['ip_address'] as String?,
      lastAccess: DateTime.parse(json['last_access'] as String),
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

