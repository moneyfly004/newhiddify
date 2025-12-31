import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/remote/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/auth/repositories/auth_repository_impl.dart';
import '../../features/servers/repositories/subscription_repository.dart';
import '../../features/servers/repositories/subscription_repository_impl.dart';
import '../../features/servers/repositories/node_repository.dart';
import '../../features/servers/repositories/node_repository_impl.dart';
import '../../core/services/kernel_manager.dart';
import '../../core/services/speed_test_engine.dart';
import '../../core/services/connection_manager.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/subscription_updater.dart';
import '../../core/services/kernel_logger.dart';
import '../../core/services/kernel_monitor.dart';
import '../../core/services/auto_reconnect_service.dart';
import '../../core/services/traffic_monitor.dart';
import '../../core/services/settings_service.dart';

/// 依赖注入容器
final getIt = GetIt.instance;

/// 初始化依赖注入
Future<void> setupDependencyInjection() async {
  // 共享偏好设置
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Dio 实例
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // 添加拦截器处理 Token
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getIt<SharedPreferences>().getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token 过期，清除本地存储
          await getIt<SharedPreferences>().remove('auth_token');
          await getIt<SharedPreferences>().remove('refresh_token');
          await getIt<SharedPreferences>().remove('user');
        }
        return handler.next(error);
      },
    ),
  );

  getIt.registerSingleton<Dio>(dio);

  // API 客户端
  getIt.registerSingleton<ApiClient>(
    ApiClient(dio, baseUrl: baseUrl),
  );

  // 仓库
  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(getIt<ApiClient>(), getIt<SharedPreferences>()),
  );

  getIt.registerSingleton<SubscriptionRepository>(
    SubscriptionRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerSingleton<NodeRepository>(
    NodeRepositoryImpl(getIt<ApiClient>()),
  );

  // 存储服务
  getIt.registerSingleton<StorageService>(
    StorageService(sharedPreferences),
  );

  // 服务
  getIt.registerSingleton<KernelManager>(
    KernelManager(getIt<StorageService>()),
  );

  getIt.registerSingleton<SubscriptionUpdater>(
    SubscriptionUpdater(getIt<SubscriptionRepository>()),
  );

  // 注册其他服务
  getIt.registerSingleton<KernelLogger>(
    KernelLogger(),
  );

  getIt.registerSingleton<KernelMonitor>(
    KernelMonitor(getIt<KernelManager>(), getIt<KernelLogger>()),
  );

  getIt.registerSingleton<SpeedTestEngine>(
    SpeedTestEngine(getIt<NodeRepository>()),
  );

  // ConnectionManager 必须在 AutoReconnectService 之前注册
  getIt.registerSingleton<ConnectionManager>(
    ConnectionManager(
      getIt<KernelManager>(),
      getIt<SubscriptionRepository>(),
      getIt<StorageService>(),
    ),
  );

  getIt.registerSingleton<AutoReconnectService>(
    AutoReconnectService(getIt<ConnectionManager>(), getIt<StorageService>()),
  );

  getIt.registerSingleton<TrafficMonitor>(
    TrafficMonitor(),
  );

  // 启动自动更新（每30分钟）
  getIt<SubscriptionUpdater>().startAutoUpdate();
  
  // 启动内核监控
  getIt<KernelMonitor>().startMonitoring();
  
  // 启动自动重连（如果启用）
  // getIt<AutoReconnectService>().enableAutoReconnect();
  
  // 注册设置服务
  getIt.registerSingleton<SettingsService>(
    SettingsService.instance,
  );
  
  // 初始化设置服务
  getIt<SettingsService>().initialize();
}

