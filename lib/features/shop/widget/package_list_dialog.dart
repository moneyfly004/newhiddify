import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/shop/data/package_data_providers.dart';
import 'package:hiddify/features/shop/pages/package_purchase_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PackageListDialog extends HookConsumerWidget {
  const PackageListDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(packagesListProvider);
    const shopUrl = 'https://dy.moneyfly.top';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(FluentIcons.shopping_bag_24_filled),
                  const Gap(8),
                  const Text(
                    '套餐购买',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: switch (packagesAsync) {
                AsyncData(value: final packages) => packages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('暂无可用套餐'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: packages.length,
                        cacheExtent: 500, // 优化滚动性能
                        itemBuilder: (context, index) {
                          final package = packages[index];
                          final name = package['name'] as String? ?? '未知套餐';
                          final price = (package['price'] as num?)?.toDouble() ?? 0.0;
                          final durationDays = (package['duration_days'] as num?)?.toInt() ?? 0;
                          final deviceLimit = (package['device_limit'] as num?)?.toInt() ?? 0;
                          final description = package['description'] as String? ?? '';
                          final isRecommended = package['is_recommended'] as bool? ?? false;

                          return Card(
                            key: ValueKey(package['id']), // 添加key优化重建
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: isRecommended ? 4 : 1,
                            color: isRecommended ? Theme.of(context).colorScheme.primaryContainer : null,
                            child: InkWell(
                              onTap: () {
                                // 在app内打开购买页面
                                final packageId = package['id'];
                                if (packageId != null) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PackagePurchasePage(
                                        packageId: packageId as int,
                                        package: package,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        if (isRecommended)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '推荐',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const Gap(8),
                                      Text(
                                        description,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    const Gap(12),
                                    Row(
                                      children: [
                                        Text(
                                          '¥${price.toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const Gap(16),
                                        Icon(
                                          FluentIcons.calendar_24_regular,
                                          size: 16,
                                        ),
                                        const Gap(4),
                                        Text(
                                          '${durationDays}天',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                        const Gap(16),
                                        Icon(
                                          FluentIcons.phone_24_regular,
                                          size: 16,
                                        ),
                                        const Gap(4),
                                        Text(
                                          '$deviceLimit 设备',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                AsyncLoading() => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                AsyncError(error: final error, stackTrace: final _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const Gap(16),
                          Text('加载套餐列表失败: $error'),
                          const Gap(16),
                          FilledButton(
                            onPressed: () {
                              ref.invalidate(packagesListProvider);
                            },
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                _ => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(shopUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(FluentIcons.open_24_regular),
                label: const Text('在浏览器中打开购买页面'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
