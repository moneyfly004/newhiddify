import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription/data/subscription_api.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

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
class AutoSubscriptionNotifier extends _$AutoSubscriptionNotifier with AppLogger {
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
      loggy.info("🔄 开始获取用户订阅信息...");
      final subscriptionApi = ref.read(subscriptionApiProvider);
      final subscription = await subscriptionApi.getUserSubscription();

      if (subscription != null && subscription.isNotEmpty) {
        loggy.info("✅ 获取到订阅信息: ${subscription.keys}");
        // 优先使用后端返回的完整 universal_url（后端已经拼接好了完整URL）
        String? universalUrl = subscription['universal_url'] as String?;

        // 如果没有 universal_url，则使用 subscription_url（token）进行拼接
        if (universalUrl == null || universalUrl.isEmpty) {
          final subscriptionUrl = subscription['subscription_url'] as String?;
          if (subscriptionUrl != null && subscriptionUrl.isNotEmpty) {
            // subscription_url 是 token，需要拼接成完整URL
            universalUrl = subscriptionApi.getUniversalSubscriptionUrl(subscriptionUrl);
          }
        }

        if (universalUrl != null && universalUrl.isNotEmpty) {
          // 从订阅数据中提取到期时间，格式化为名称
          String profileName = "订阅";
          final expireTimeStr = subscription['expire_time'] as String?;
          if (expireTimeStr != null && expireTimeStr.isNotEmpty && expireTimeStr != "未设置") {
            try {
              // 解析日期时间字符串 "2006-01-02 15:04:05"
              final expireTime = DateTime.parse(expireTimeStr);
              // 格式化为 "到期: 2024-12-31"
              final year = expireTime.year;
              final month = expireTime.month.toString().padLeft(2, '0');
              final day = expireTime.day.toString().padLeft(2, '0');
              profileName = "到期: $year-$month-$day";
            } catch (e) {
              // 如果解析失败，使用原始字符串
              profileName = "到期: $expireTimeStr";
            }
          }

          // 创建 RemoteProfileEntity，设置名称和更新间隔为1小时
          final profileId = const Uuid().v4();
          final baseProfile = RemoteProfileEntity(
            id: profileId,
            active: true,
            name: profileName,
            url: universalUrl,
            lastUpdate: DateTime.now(),
            options: ProfileOptions(
              updateInterval: const Duration(hours: 1),
            ),
          );

          // 添加到profile repository，并设置为active
          loggy.info("📝 正在添加订阅到profile: name=$profileName, url=$universalUrl");
          final profileRepo = ref.read(profileRepositoryProvider).requireValue;
          final result = await profileRepo.add(baseProfile).run();
          result.fold(
            (failure) {
              loggy.error("❌ 自动获取订阅失败: $failure");
            },
            (_) {
              loggy.info("✅ 订阅已生效！已添加到profile并设置为active，名称: $profileName");
              loggy.info("🎉 套餐购买成功，订阅已激活");
            },
          );
        } else {
          loggy.warning("⚠️ 订阅数据中没有有效的订阅URL");
        }
      } else {
        loggy.warning("⚠️ 获取订阅返回null或空数据，可能是用户没有订阅或API调用失败");
      }
    } catch (e, stackTrace) {
      loggy.error("❌ 自动获取订阅异常", e, stackTrace);
    }
  }

  /// 手动刷新订阅
  Future<void> refreshSubscription() async {
    await _fetchAndUpdateSubscription();
  }
}
