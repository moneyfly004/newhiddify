import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/connection/pages/home_page.dart';
import '../../features/servers/pages/servers_list_page.dart';
import '../../features/servers/pages/speed_test_page.dart';
import '../../features/settings/pages/comprehensive_settings_page.dart';

/// 应用路由配置
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/servers',
        name: 'servers',
        builder: (context, state) => const ServersListPage(),
      ),
      GoRoute(
        path: '/speed-test',
        name: 'speed-test',
        builder: (context, state) => const SpeedTestPage(),
      ),
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const ComprehensiveSettingsPage(),
            ),
    ],
    redirect: (context, state) {
      // TODO: 根据认证状态进行路由重定向
      return null;
    },
  );
}

