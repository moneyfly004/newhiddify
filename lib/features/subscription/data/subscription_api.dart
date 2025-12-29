import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class SubscriptionApi with ExceptionHandler, InfraLogger {
  SubscriptionApi({
    required this.httpClient,
    required this.baseUrl,
  });

  final DioHttpClient httpClient;
  final String baseUrl;

  String get _apiBase => '$baseUrl/api/v1';

  /// 获取用户订阅列表
  Future<List<Map<String, dynamic>>> getUserSubscriptions() async {
    try {
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/subscriptions',
        proxyOnly: false,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!['data'] as List<dynamic>?;
        if (data != null) {
          return data.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      }
      return [];
    } catch (e, stackTrace) {
      loggy.warning("获取订阅列表失败", e, stackTrace);
      return [];
    }
  }

  /// 获取用户订阅（单个）
  Future<Map<String, dynamic>?> getUserSubscription() async {
    try {
      loggy.info("📡 请求用户订阅信息...");
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/subscriptions/user-subscription',
        proxyOnly: false,
      );

      loggy.debug("订阅信息响应: statusCode=${response.statusCode}");

      if (response.statusCode == 200 && response.data != null) {
        // 后端返回格式：utils.SuccessResponse(c, http.StatusOK, "", subscriptionData)
        // 实际响应格式可能是 { "data": {...} } 或直接 {...}
        final responseData = response.data!;
        final data = responseData['data'] as Map<String, dynamic>? ?? responseData as Map<String, dynamic>?;

        if (data != null) {
          final expireTime = data['expire_time'] as String?;
          loggy.info("✅ 获取订阅信息成功: expireTime=$expireTime");
        } else {
          loggy.warning("⚠️ 订阅信息数据为空");
        }

        return data;
      } else {
        loggy.warning("⚠️ 获取订阅信息失败: statusCode=${response.statusCode}");
      }
      return null;
    } catch (e, stackTrace) {
      loggy.error("❌ 获取用户订阅异常", e, stackTrace);
      return null;
    }
  }

  /// 获取订阅配置URL（通用格式）
  String getUniversalSubscriptionUrl(String subscriptionUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // 如果subscriptionUrl已经是完整URL，直接返回
    if (subscriptionUrl.startsWith('http://') || subscriptionUrl.startsWith('https://')) {
      return '$subscriptionUrl?t=$timestamp';
    }
    // 否则使用API端点
    return '$_apiBase/subscriptions/universal/$subscriptionUrl?t=$timestamp';
  }

  /// 获取订阅配置URL（Clash格式）
  String getClashSubscriptionUrl(String subscriptionUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return '$_apiBase/subscriptions/clash/$subscriptionUrl?t=$timestamp';
  }
}
