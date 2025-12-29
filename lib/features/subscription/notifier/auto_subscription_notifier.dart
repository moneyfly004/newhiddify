import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/subscription/data/subscription_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_subscription_notifier.g.dart';

@Riverpod(keepAlive: true)
SubscriptionApi subscriptionApi(SubscriptionApiRef ref) {
  const baseUrl = 'https://dy.moneyfly.top';
  return SubscriptionApi(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

@Riverpod(keepAlive: true)
class AutoSubscriptionNotifier extends _$AutoSubscriptionNotifier {
  @override
  Future<void> build() async {
    // 监听认证状态变化，自动获取订阅
    ref.listen(authNotifierProvider, (previous, next) {
      final previousUser = previous?.valueOrNull?.valueOrNull;
      final nextUser = next.valueOrNull?.valueOrNull;
      // 当用户从未登录变为已登录时，立即获取订阅
      if (previousUser == null && nextUser != null) {
        // 用户刚登录，立即获取订阅
        _fetchAndUpdateSubscription();
      }
    });

    // 如果当前已登录，立即获取订阅
    final authState = ref.read(authNotifierProvider);
    final user = authState.valueOrNull?.valueOrNull;
    if (user != null) {
      await _fetchAndUpdateSubscription();
    }
  }

  /// 获取并更新订阅
  Future<void> _fetchAndUpdateSubscription() async {
    try {
      final subscriptionApi = ref.read(subscriptionApiProvider);
      final subscription = await subscriptionApi.getUserSubscription();

      if (subscription != null) {
        final subscriptionUrl = subscription['subscription_url'] as String?;
        if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
          // 构建完整的订阅URL
          String universalUrl;
          if (subscriptionUrl.startsWith('http://') || subscriptionUrl.startsWith('https://')) {
            // 如果已经是完整URL，直接使用
            universalUrl = subscriptionUrl;
          } else {
            // 否则使用API获取通用格式
            universalUrl = subscriptionApi.getUniversalSubscriptionUrl(subscriptionUrl);
          }
          
          // 添加到profile repository
          final profileRepo = ref.read(profileRepositoryProvider).requireValue;
          final result = await profileRepo.addByUrl(universalUrl, markAsActive: true).run();
          result.fold(
            (failure) {
              // 静默失败，记录日志
              print('自动获取订阅失败: $failure');
            },
            (_) {
              // 成功
              print('自动获取订阅成功');
            },
          );
        }
      }
    } catch (e) {
      // 静默失败，记录日志
      print('自动获取订阅异常: $e');
    }
  }

  /// 手动刷新订阅
  Future<void> refreshSubscription() async {
    await _fetchAndUpdateSubscription();
  }
}

