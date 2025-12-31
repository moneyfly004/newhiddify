import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../data/remote/api_client.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/retry_helper.dart';
import 'subscription_repository.dart';
import '../models/subscription.dart';

/// 订阅仓库实现
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final ApiClient _apiClient;

  SubscriptionRepositoryImpl(this._apiClient);

  @override
  Future<List<Subscription>> getSubscriptions() async {
    // 先尝试从缓存获取
    final cached = await CacheManager.getCache<List<dynamic>>('subscriptions');
    if (cached != null) {
      return cached
          .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    try {
      final response = await RetryHelper.retry(
        action: () => _apiClient.getSubscriptions(),
        maxRetries: 3,
      );
      
      final data = response.data;
      List<Subscription> subscriptions = [];
      
      if (data is List) {
        subscriptions = data
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (data is Map && data['data'] is List) {
        subscriptions = (data['data'] as List)
            .map((json) => Subscription.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // 缓存结果
      if (subscriptions.isNotEmpty) {
        await CacheManager.setCache(
          'subscriptions',
          subscriptions.map((s) => s.toJson()).toList(),
          expiry: const Duration(minutes: 5),
        );
      }

      return subscriptions;
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取订阅列表失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<Subscription> getSubscription(String id) async {
    try {
      return await _apiClient.getSubscription(id);
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取订阅详情失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<String> getClashConfig(String subscriptionUrl) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      return await _apiClient.getClashConfig(subscriptionUrl, timestamp);
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取配置失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }

  @override
  Future<String> getUniversalConfig(String subscriptionUrl) async {
    try {
      debugPrint('[SubscriptionRepo] 获取通用订阅配置');
      debugPrint('[SubscriptionRepo] 订阅URL: $subscriptionUrl');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final result = await _apiClient.getUniversalConfig(subscriptionUrl, timestamp);
      debugPrint('[SubscriptionRepo] 获取成功，内容长度: ${result.length}');
      debugPrint('[SubscriptionRepo] 内容前100字符: ${result.length > 100 ? result.substring(0, 100) : result}');
      return result;
    } on DioException catch (e) {
      debugPrint('[SubscriptionRepo] 获取通用订阅配置失败: ${e.type}');
      debugPrint('[SubscriptionRepo] 响应状态码: ${e.response?.statusCode}');
      debugPrint('[SubscriptionRepo] 响应数据: ${e.response?.data}');
      if (e.response != null) {
        final message = e.response?.data['message'] as String? ??
            '获取配置失败';
        throw Exception(message);
      }
      throw Exception('网络错误，请检查网络连接');
    }
  }
}

