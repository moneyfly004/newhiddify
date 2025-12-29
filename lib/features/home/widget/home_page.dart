import 'package:dartx/dartx.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/router.dart';
import 'package:hiddify/core/router/routes.dart';
import 'package:hiddify/features/common/nested_app_bar.dart';
import 'package:hiddify/features/config_option/data/config_option_repository.dart';
import 'package:hiddify/features/subscription/notifier/auto_subscription_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/empty_profiles_home_body.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_footer.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final hasAnyProfile = ref.watch(hasAnyProfileProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomScrollView(
            slivers: [
              NestedAppBar(
                title: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: t.general.appTitle),
                      const TextSpan(text: " "),
                      const WidgetSpan(
                        child: AppVersionLabel(),
                        alignment: PlaceholderAlignment.middle,
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => const QuickSettingsRoute().push(context),
                    icon: const Icon(FluentIcons.options_24_filled),
                    tooltip: t.config.quickSettings,
                  ),
                  // 保留刷新订阅按钮，允许用户手动更新订阅
                  IconButton(
                    onPressed: () async {
                      // 手动刷新订阅
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('正在刷新订阅...'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      try {
                        await ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('订阅刷新成功'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('订阅刷新失败: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(FluentIcons.arrow_sync_24_regular),
                    tooltip: '刷新订阅',
                  ),
                ],
              ),
              switch (activeProfile) {
                AsyncData(value: final profile?) => MultiSliver(
                    children: [
                      ProfileTile(profile: profile, isMain: true),
                      // 添加模式切换开关
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '连接模式',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const Gap(8),
                                  SegmentedButton<ServiceMode>(
                                    segments: ServiceMode.choices
                                        .map(
                                          (e) => ButtonSegment<ServiceMode>(
                                            value: e,
                                            label: Text(
                                              e.presentShort(t),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    selected: {ref.watch(ConfigOptions.serviceMode)},
                                    onSelectionChanged: (newSet) {
                                      ref.read(ConfigOptions.serviceMode.notifier).update(newSet.first);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ConnectionButton(),
                                  ActiveProxyDelayIndicator(),
                                ],
                              ),
                            ),
                            if (MediaQuery.sizeOf(context).width < 840) const ActiveProxyFooter(),
                          ],
                        ),
                      ),
                    ],
                  ),
                AsyncData() => switch (hasAnyProfile) {
                    AsyncData(value: true) => const EmptyActiveProfileHomeBody(),
                    _ => const EmptyProfilesHomeBody(),
                  },
                AsyncError(:final error) => SliverErrorBodyPlaceholder(t.presentShortError(error)),
                _ => const SliverToBoxAdapter(),
              },
            ],
          ),
        ],
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.about.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 1,
        ),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
