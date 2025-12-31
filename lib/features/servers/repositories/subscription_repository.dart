import '../models/subscription.dart';

/// 订阅仓库接口
abstract class SubscriptionRepository {
  /// 获取订阅列表
  Future<List<Subscription>> getSubscriptions();

  /// 获取订阅详情
  Future<Subscription> getSubscription(String id);

  /// 获取 Clash 配置
  Future<String> getClashConfig(String subscriptionUrl);

  /// 获取通用订阅配置
  Future<String> getUniversalConfig(String subscriptionUrl);
}

