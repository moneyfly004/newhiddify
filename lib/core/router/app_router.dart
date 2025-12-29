import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/routes.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/deep_link/notifier/deep_link_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'app_router.g.dart';

bool _debugMobileRouter = false;

final useMobileRouter = !PlatformUtils.isDesktop || (kDebugMode && _debugMobileRouter);
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// TODO: test and improve handling of deep link
@riverpod
GoRouter router(RouterRef ref) {
  final notifier = ref.watch(routerListenableProvider.notifier);
  final deepLink = ref.listen(
    deepLinkNotifierProvider,
    (_, next) async {
      if (next case AsyncData(value: final link?)) {
        await ref.state.push(AddProfileRoute(url: link.url).location);
      }
    },
  );
  final initialLink = deepLink.read();
  String initialLocation = const HomeRoute().location;
  if (initialLink case AsyncData(value: final link?)) {
    initialLocation = AddProfileRoute(url: link.url).location;
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    debugLogDiagnostics: true,
    routes: [
      if (useMobileRouter) $mobileWrapperRoute else $desktopWrapperRoute,
      $introRoute,
      $loginRoute,
      $registerRoute,
      $forgotPasswordRoute,
      $resetPasswordRoute,
    ],
    refreshListenable: notifier,
    redirect: notifier.redirect,
    observers: [
      SentryNavigatorObserver(),
    ],
  );
}

final tabLocations = [
  const HomeRoute().location,
  const ProxiesRoute().location,
  const ConfigOptionsRoute().location,
  const SettingsRoute().location,
  const LogsOverviewRoute().location,
  const ShopRoute().location,
  const AboutRoute().location,
  null, // 退出登录，特殊处理
];

int getCurrentIndex(BuildContext context) {
  final String location = GoRouterState.of(context).uri.path;
  if (location == const HomeRoute().location) return 0;
  var index = 0;
  for (final tab in tabLocations.sublist(1)) {
    index++;
    if (tab != null && location.startsWith(tab)) return index;
  }
  return 0;
}

void switchTab(int index, BuildContext context) {
  assert(index >= 0 && index < tabLocations.length);
  final location = tabLocations[index];
  // 退出登录特殊处理
  if (location == null) {
    // 这是退出登录按钮，需要从 context 获取 authNotifierProvider
    // 但由于这里没有 ref，我们需要通过其他方式处理
    // 实际上，退出登录应该在 NavigationDestination 的 onTap 中处理
    // 但 NavigationDestination 不支持自定义 onTap
    // 所以我们创建一个特殊的处理方式
    return;
  }
  return context.go(location);
}

@riverpod
class RouterListenable extends _$RouterListenable with AppLogger implements Listenable {
  VoidCallback? _routerListener;
  bool _introCompleted = false;

  @override
  Future<void> build() async {
    _introCompleted = ref.watch(Preferences.introCompleted);

    ref.listenSelf((_, __) {
      if (state.isLoading) return;
      loggy.debug("triggering listener");
      _routerListener?.call();
    });
  }

// ignore: avoid_build_context_in_providers
  String? redirect(BuildContext context, GoRouterState state) {
    // if (this.state.isLoading || this.state.hasError) return null;

    final currentPath = state.uri.path;
    final isIntro = currentPath == const IntroRoute().location;
    final isLogin = currentPath == const LoginRoute().location || currentPath == '/auth/login';
    final isRegister = currentPath == const RegisterRoute().location || currentPath == '/auth/register';
    final isForgotPassword = currentPath == const ForgotPasswordRoute().location || currentPath == '/auth/forgot-password';
    final isResetPassword = currentPath.startsWith(const ResetPasswordRoute().location) || currentPath.startsWith('/auth/reset-password');
    final isAuthPage = isLogin || isRegister || isForgotPassword || isResetPassword;

    // 检查登录状态
    final authState = ref.read(authNotifierProvider);
    final isAuthenticated = authState.valueOrNull?.valueOrNull != null;

    if (!_introCompleted) {
      // 如果未完成介绍页，且不在介绍页，重定向到介绍页
      if (!isIntro) {
        return const IntroRoute().location;
      }
      return null;
    } else if (isIntro) {
      // 如果已完成介绍页，但在介绍页，重定向到主页或登录页
      if (isAuthenticated) {
        return const HomeRoute().location;
      } else {
        return const LoginRoute().location;
      }
    }

    // 如果未登录且不在认证页面，重定向到登录页
    if (!isAuthenticated && !isAuthPage && !isIntro) {
      return const LoginRoute().location;
    }

    // 如果已登录且在认证页面（登录、注册、忘记密码），重定向到主页
    if (isAuthenticated && isAuthPage) {
      return const HomeRoute().location;
    }

    // 允许未登录用户访问认证页面
    return null;
  }

  @override
  void addListener(VoidCallback listener) {
    _routerListener = listener;
  }

  @override
  void removeListener(VoidCallback listener) {
    _routerListener = null;
  }
}
