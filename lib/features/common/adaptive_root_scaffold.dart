import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/router.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/stats/widget/side_bar_stats_overview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

abstract interface class RootScaffold {
  static final stateKey = GlobalKey<ScaffoldState>();

  static bool canShowDrawer(BuildContext context) => Breakpoints.small.isActive(context);
}

class AdaptiveRootScaffold extends HookConsumerWidget {
  const AdaptiveRootScaffold(this.navigator, {super.key});

  final Widget navigator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isAuthenticated = ref.watch(
      authNotifierProvider.select((state) => state.valueOrNull?.valueOrNull != null),
    );

    // 计算当前选中的索引，考虑动态的 destinations 列表
    final routeIndex = getCurrentIndex(context);
    int selectedIndex = routeIndex;
    // 如果路由索引是 shop(5) 或 about(6)，需要映射到 destinations 索引
    if (routeIndex == 5) {
      // shop 在 destinations 中的索引是 5（如果已登录）
      selectedIndex = isAuthenticated ? 5 : -1; // 未登录时 shop 不存在
    } else if (routeIndex == 6) {
      // about 在 destinations 中的索引：已登录是 6，未登录是 5
      selectedIndex = isAuthenticated ? 6 : 5;
    }

    // 优化：使用 useMemoized 缓存 destinations 列表，避免每次重建
    final destinations = useMemoized(
        () => [
              NavigationDestination(
                icon: const Icon(FluentIcons.power_20_filled),
                label: t.home.pageTitle,
              ),
              NavigationDestination(
                icon: const Icon(FluentIcons.filter_20_filled),
                label: t.proxies.pageTitle,
              ),
              NavigationDestination(
                icon: const Icon(FluentIcons.box_edit_20_filled),
                label: t.config.pageTitle,
              ),
              NavigationDestination(
                icon: const Icon(FluentIcons.settings_20_filled),
                label: t.settings.pageTitle,
              ),
              NavigationDestination(
                icon: const Icon(FluentIcons.document_text_20_filled),
                label: t.logs.pageTitle,
              ),
              if (isAuthenticated)
                NavigationDestination(
                  icon: const Icon(FluentIcons.shopping_bag_20_filled),
                  label: '套餐购买',
                ),
              NavigationDestination(
                icon: const Icon(FluentIcons.info_20_filled),
                label: t.about.pageTitle,
              ),
              if (isAuthenticated)
                NavigationDestination(
                  icon: const Icon(FluentIcons.sign_out_20_filled),
                  label: '退出登录',
                ),
            ],
        [isAuthenticated, t.home.pageTitle, t.proxies.pageTitle, t.config.pageTitle, t.settings.pageTitle, t.logs.pageTitle, t.about.pageTitle]);

    return _CustomAdaptiveScaffold(
      selectedIndex: selectedIndex,
      onSelectedIndexChange: (index) {
        RootScaffold.stateKey.currentState?.closeDrawer();
        // 映射 destinations 索引到 tabLocations 索引
        // tabLocations: [home(0), proxies(1), config(2), settings(3), logs(4), shop(5), about(6), logout(null)]
        // destinations（已登录）: [home(0), proxies(1), config(2), settings(3), logs(4), shop(5), about(6), logout(7)]
        // destinations（未登录）: [home(0), proxies(1), config(2), settings(3), logs(4), about(5)]

        // 检查是否是退出登录按钮
        if (isAuthenticated && index == destinations.length - 1) {
          // 最后一个按钮是退出登录
          ref.read(authNotifierProvider.notifier).logout().then((result) {
            result.fold(
              (failure) {
                if (context.mounted) context.go('/login');
              },
              (_) {
                if (context.mounted) context.go('/login');
              },
            );
          });
          return;
        }

        // 映射到 tabLocations 索引
        int routeIndex = index;
        if (isAuthenticated) {
          // 已登录：索引0-4直接对应，索引5是shop，索引6是about
          if (index == 5) {
            routeIndex = 5; // shop
          } else if (index == 6) {
            routeIndex = 6; // about
          }
        } else {
          // 未登录：索引0-4直接对应，索引5是about（对应tabLocations[6]）
          if (index == 5) {
            routeIndex = 6; // about
          }
        }
        switchTab(routeIndex, context);
      },
      destinations: destinations,
      drawerDestinationRange: useMobileRouter ? (2, null) : (0, null),
      bottomDestinationRange: (0, 2),
      useBottomSheet: useMobileRouter,
      sidebarTrailing: const Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SideBarStatsOverview(),
        ),
      ),
      body: navigator,
    );
  }
}

class _CustomAdaptiveScaffold extends HookConsumerWidget {
  const _CustomAdaptiveScaffold({
    required this.selectedIndex,
    required this.onSelectedIndexChange,
    required this.destinations,
    required this.drawerDestinationRange,
    required this.bottomDestinationRange,
    this.useBottomSheet = false,
    this.sidebarTrailing,
    required this.body,
  });

  final int selectedIndex;
  final Function(int) onSelectedIndexChange;
  final List<NavigationDestination> destinations;
  final (int, int?) drawerDestinationRange;
  final (int, int?) bottomDestinationRange;
  final bool useBottomSheet;
  final Widget? sidebarTrailing;
  final Widget body;

  List<NavigationDestination> destinationsSlice((int, int?) range) => destinations.sublist(range.$1, range.$2);

  int? selectedWithOffset((int, int?) range) {
    final index = selectedIndex - range.$1;
    return index < 0 || (range.$2 != null && index > (range.$2! - 1)) ? null : index;
  }

  void selectWithOffset(int index, (int, int?) range) => onSelectedIndexChange(index + range.$1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: RootScaffold.stateKey,
      drawer: Breakpoints.small.isActive(context)
          ? Drawer(
              width: (MediaQuery.sizeOf(context).width * 0.88).clamp(1, 304),
              child: Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      extended: true,
                      selectedIndex: selectedWithOffset(drawerDestinationRange),
                      destinations: destinationsSlice(drawerDestinationRange).map((dest) => AdaptiveScaffold.toRailDestination(dest)).toList(),
                      onDestinationSelected: (index) => selectWithOffset(index, drawerDestinationRange),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: AdaptiveLayout(
        primaryNavigation: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig>{
            Breakpoints.medium: SlotLayout.from(
              key: const Key('primaryNavigation'),
              builder: (_) => AdaptiveScaffold.standardNavigationRail(
                selectedIndex: selectedIndex,
                destinations: destinations.map((dest) => AdaptiveScaffold.toRailDestination(dest)).toList(),
                onDestinationSelected: onSelectedIndexChange,
              ),
            ),
            Breakpoints.large: SlotLayout.from(
              key: const Key('primaryNavigation1'),
              builder: (_) => AdaptiveScaffold.standardNavigationRail(
                extended: true,
                selectedIndex: selectedIndex,
                destinations: destinations.map((dest) => AdaptiveScaffold.toRailDestination(dest)).toList(),
                onDestinationSelected: onSelectedIndexChange,
                trailing: sidebarTrailing,
              ),
            ),
          },
        ),
        body: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig?>{
            Breakpoints.standard: SlotLayout.from(
              key: const Key('body'),
              inAnimation: AdaptiveScaffold.fadeIn,
              outAnimation: AdaptiveScaffold.fadeOut,
              builder: (context) => body,
            ),
          },
        ),
      ),
      // AdaptiveLayout bottom sheet has accessibility issues
      bottomNavigationBar: useBottomSheet && Breakpoints.small.isActive(context)
          ? NavigationBar(
              selectedIndex: selectedWithOffset(bottomDestinationRange) ?? 0,
              destinations: destinationsSlice(bottomDestinationRange),
              onDestinationSelected: (index) => selectWithOffset(index, bottomDestinationRange),
            )
          : null,
    );
  }
}
