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

  /// 获取支付方式列表
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      loggy.debug("获取支付方式列表");
      final response = await httpClient.get<Map<String, dynamic>>(
        '$_apiBase/payment-methods/active',
        proxyOnly: false,
      );

      if (response.statusCode == 200 && response.data != null) {
        // 后端返回格式: { success: true, data: [...] }
        final responseData = response.data!;
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          if (data is List) {
            return data.map((e) => e as Map<String, dynamic>).toList();
          }
        }
        // 尝试直接返回数组格式（兼容其他格式）
        if (responseData['data'] is List) {
          return (responseData['data'] as List).map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      }
      return [];
    } catch (e, stackTrace) {
      loggy.warning("获取支付方式列表失败", e, stackTrace);
      return [];
    }
  }

  /// 支付订单（为已创建的订单生成支付链接）
  Future<Map<String, dynamic>?> payOrder({
    required String orderNo,
    required int paymentMethodId,
  }) async {
    try {
      loggy.debug("支付订单: orderNo=$orderNo, paymentMethodId=$paymentMethodId");
      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/orders/$orderNo/pay',
        data: {
          'payment_method_id': paymentMethodId,
        },
        proxyOnly: false,
      );

      loggy.debug("支付订单响应: statusCode=${response.statusCode}, data=${response.data}");

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          // 支持两种响应格式：直接返回数据或包装在 'data' 字段中
          final paymentData = data['data'] as Map<String, dynamic>? ?? data;
          loggy.info("✅ 支付链接生成成功: orderNo=${paymentData['order_no']}");
          return paymentData;
        }
        loggy.warning("支付订单响应数据为空");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '生成支付链接失败: HTTP ${response.statusCode}';
        loggy.error("❌ 生成支付链接失败: $errorMsg, statusCode=${response.statusCode}");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("❌ 支付订单异常", e, stackTrace);
      rethrow;
    }
  }

  /// 创建订单
  Future<Map<String, dynamic>?> createOrder({
    required int packageId,
    String? couponCode,
    String? paymentMethod,
  }) async {
    try {
      loggy.debug("创建订单: packageId=$packageId, couponCode=$couponCode, paymentMethod=$paymentMethod");
      loggy.debug("创建订单URL: $_apiBase/orders");

      // 注意：无法直接访问 _accessToken，但可以通过日志确认
      loggy.debug("准备创建订单，HTTP客户端应该已设置Authorization header");

      final response = await httpClient.post<Map<String, dynamic>>(
        '$_apiBase/orders',
        data: {
          'package_id': packageId,
          if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
          if (paymentMethod != null && paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
        },
        proxyOnly: false,
      );

      loggy.debug("订单创建响应: statusCode=${response.statusCode}, data=${response.data}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data != null) {
          // 支持两种响应格式：直接返回数据或包装在 'data' 字段中
          final orderData = data['data'] as Map<String, dynamic>? ?? data;
          final orderNo = orderData['order_no'] as String? ?? '';
          final status = orderData['status'] as String? ?? '';
          final amount = orderData['final_amount'] ?? orderData['amount'] ?? 0;
          final hasPaymentUrl = (orderData['payment_url'] != null || orderData['payment_qr_code'] != null);

          loggy.info("✅ 订单创建成功: orderNo=$orderNo, status=$status, amount=¥$amount, hasPaymentUrl=$hasPaymentUrl");

          if (status == 'paid') {
            loggy.info("🎉 订单已支付，订阅将自动激活");
          } else if (hasPaymentUrl) {
            loggy.info("💳 支付链接已生成，等待用户支付");
          } else {
            loggy.warning("⚠️ 订单创建成功但无支付链接");
          }

          return orderData;
        }
        loggy.warning("⚠️ 订单创建响应数据为空");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '创建订单失败: HTTP ${response.statusCode}';
        loggy.error("❌ 订单创建失败: $errorMsg, statusCode=${response.statusCode}");
        loggy.error("响应数据: ${response.data}");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("❌ 创建订单异常", e, stackTrace);
      loggy.error("异常类型: ${e.runtimeType}");
      // 如果是DioException，记录更详细的信息
      if (e.toString().contains('DioException')) {
        loggy.error("DioException详情: $e");
      }
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 查询订单状态
  Future<Map<String, dynamic>?> getOrderStatus(String orderNo) async {
    try {
      loggy.info("📊 查询订单状态: orderNo=$orderNo");
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
          final status = orderData['status'] as String?;
          loggy.info("📦 订单状态: orderNo=$orderNo, status=$status");

          if (status == 'paid') {
            loggy.info("✅ 订单已支付: orderNo=$orderNo");
          }

          return orderData;
        }
        loggy.warning("⚠️ 订单状态查询响应数据为空: orderNo=$orderNo");
        return null;
      } else {
        final errorMsg = response.data?['message'] as String? ?? response.data?['error'] as String? ?? '查询订单状态失败: HTTP ${response.statusCode}';
        loggy.error("❌ 查询订单状态失败: orderNo=$orderNo, error=$errorMsg");
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      loggy.error("❌ 查询订单状态异常: orderNo=$orderNo", e, stackTrace);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }
}
