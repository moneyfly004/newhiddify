import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class PackageApi with InfraLogger {
  PackageApi({
    required this.httpClient,
    required this.baseUrl,
  });

  final DioHttpClient httpClient;
  final String baseUrl;

  String get _apiBase => '$baseUrl/api/v1';

  /// 获取套餐列表
  Future<List<Map<String, dynamic>>> getPackages() async {
    try {
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/packages',
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
      loggy.warning("获取套餐列表失败", e, stackTrace);
      return [];
    }
  }

  /// 验证优惠券
  Future<Map<String, dynamic>?> verifyCoupon({
    required String code,
    required double amount,
    int? packageId,
  }) async {
    try {
      loggy.debug("验证优惠券: code=$code, amount=$amount, packageId=$packageId");
      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/coupons/verify',
        data: {
          'code': code,
          'amount': amount,
          if (packageId != null) 'package_id': packageId,
        },
        proxyOnly: false,
      );

      loggy.debug("优惠券验证响应: statusCode=${response.statusCode}, data=${response.data}");

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          // 支持两种响应格式：直接返回数据或包装在 'data' 字段中
          final couponData = data['data'] as Map<String, dynamic>? ?? data;
          loggy.debug("优惠券数据: $couponData");
          return couponData;
        }
        loggy.warning("优惠券验证响应数据为空");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '验证优惠券失败: HTTP ${response.statusCode}';
        loggy.warning("优惠券验证失败: $errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("验证优惠券异常", e, stackTrace);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 创建订单
  Future<Map<String, dynamic>?> createOrder({
    required int packageId,
    String? couponCode,
  }) async {
    try {
      loggy.debug("创建订单: packageId=$packageId, couponCode=$couponCode");
      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/orders',
        data: {
          'package_id': packageId,
          if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
        },
        proxyOnly: false,
      );

      loggy.debug("订单创建响应: statusCode=${response.statusCode}, data=${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data != null) {
          // 支持两种响应格式：直接返回数据或包装在 'data' 字段中
          final orderData = data['data'] as Map<String, dynamic>? ?? data;
          loggy.debug("订单数据: $orderData");
          return orderData;
        }
        loggy.warning("订单创建响应数据为空");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '创建订单失败: HTTP ${response.statusCode}';
        loggy.warning("订单创建失败: $errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("创建订单异常", e, stackTrace);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 查询订单状态
  Future<Map<String, dynamic>?> getOrderStatus(String orderNo) async {
    try {
      loggy.debug("查询订单状态: orderNo=$orderNo");
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/orders/$orderNo/status',
        proxyOnly: false,
      );

      loggy.debug("订单状态查询响应: statusCode=${response.statusCode}, data=${response.data}");

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          // 支持两种响应格式：直接返回数据或包装在 'data' 字段中
          final orderData = data['data'] as Map<String, dynamic>? ?? data;
          loggy.debug("订单状态数据: $orderData");
          return orderData;
        }
        loggy.warning("订单状态查询响应数据为空");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '查询订单状态失败: HTTP ${response.statusCode}';
        loggy.warning("查询订单状态失败: $errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("查询订单状态异常", e, stackTrace);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }
}
