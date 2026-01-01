import 'dart:async';
import '../models/app_settings.dart';
import '../utils/logger.dart';

/// 设置管理服务
class SettingsService {
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  
  SettingsService._();
  
  AppSettings? _settings;
  final _settingsController = StreamController<AppSettings>.broadcast();
  
  /// 设置流
  Stream<AppSettings> get settingsStream => _settingsController.stream;
  
  /// 当前设置
  AppSettings get settings => _settings ?? AppSettings();
  
  /// 初始化
  Future<void> initialize() async {
    try {
      _settings = await AppSettings.load();
      // 确保服务模式是 VPN（如果之前被设置为代理，强制重置为 VPN）
      if (_settings!.serviceMode != ServiceMode.vpn) {
        Logger.info('检测到服务模式为代理，强制重置为 VPN 模式');
        _settings = _settings!.copyWith(serviceMode: ServiceMode.vpn);
        await _settings!.save();
      }
      _settingsController.add(_settings!);
      Logger.info('设置加载成功，服务模式: ${_settings!.serviceMode.name}');
    } catch (e) {
      Logger.error('设置加载失败', e);
      _settings = AppSettings();
    }
  }
  
  /// 更新设置
  Future<void> updateSettings(AppSettings newSettings) async {
    try {
      await newSettings.save();
      _settings = newSettings;
      _settingsController.add(newSettings);
      Logger.info('设置更新成功');
    } catch (e) {
      Logger.error('设置更新失败', e);
      rethrow;
    }
  }
  
  /// 更新单个设置项
  Future<void> update<T>(String key, T value) async {
    final currentSettings = _settings ?? AppSettings();
    AppSettings newSettings;
    
    switch (key) {
      case 'autoConnect':
        newSettings = currentSettings.copyWith(autoConnect: value as bool);
        break;
      case 'nightMode':
        newSettings = currentSettings.copyWith(nightMode: value as NightMode);
        break;
      case 'serviceMode':
        newSettings = currentSettings.copyWith(serviceMode: value as ServiceMode);
        break;
      case 'tunImplementation':
        newSettings = currentSettings.copyWith(tunImplementation: value as TunImplementation);
        break;
      case 'mtu':
        newSettings = currentSettings.copyWith(mtu: value as int);
        break;
      case 'speedInterval':
        newSettings = currentSettings.copyWith(speedInterval: value as int);
        break;
      case 'enableTrafficStatistics':
        newSettings = currentSettings.copyWith(enableTrafficStatistics: value as bool);
        break;
      case 'showDirectSpeed':
        newSettings = currentSettings.copyWith(showDirectSpeed: value as bool);
        break;
      case 'alwaysShowAddress':
        newSettings = currentSettings.copyWith(alwaysShowAddress: value as bool);
        break;
      case 'meteredNetwork':
        newSettings = currentSettings.copyWith(meteredNetwork: value as bool);
        break;
      case 'acquireWakeLock':
        newSettings = currentSettings.copyWith(acquireWakeLock: value as bool);
        break;
      case 'logLevel':
        newSettings = currentSettings.copyWith(logLevel: value as LogLevel);
        break;
      case 'enableProxyApps':
        newSettings = currentSettings.copyWith(enableProxyApps: value as bool);
        break;
      case 'proxyAppList':
        newSettings = currentSettings.copyWith(proxyAppList: value as List<String>);
        break;
      case 'bypassLan':
        newSettings = currentSettings.copyWith(bypassLan: value as bool);
        break;
      case 'bypassLanInCore':
        newSettings = currentSettings.copyWith(bypassLanInCore: value as bool);
        break;
      case 'trafficSniffing':
        newSettings = currentSettings.copyWith(trafficSniffing: value as TrafficSniffing);
        break;
      case 'resolveDestination':
        newSettings = currentSettings.copyWith(resolveDestination: value as bool);
        break;
      case 'ipv6Mode':
        newSettings = currentSettings.copyWith(ipv6Mode: value as Ipv6Mode);
        break;
      case 'rulesProvider':
        newSettings = currentSettings.copyWith(rulesProvider: value as RulesProvider);
        break;
      case 'remoteDns':
        newSettings = currentSettings.copyWith(remoteDns: value as String);
        break;
      case 'domainStrategyForRemote':
        newSettings = currentSettings.copyWith(domainStrategyForRemote: value as DomainStrategy);
        break;
      case 'directDns':
        newSettings = currentSettings.copyWith(directDns: value as String);
        break;
      case 'domainStrategyForDirect':
        newSettings = currentSettings.copyWith(domainStrategyForDirect: value as DomainStrategy);
        break;
      case 'enableDnsRouting':
        newSettings = currentSettings.copyWith(enableDnsRouting: value as bool);
        break;
      case 'enableFakeDns':
        newSettings = currentSettings.copyWith(enableFakeDns: value as bool);
        break;
      case 'mixedPort':
        newSettings = currentSettings.copyWith(mixedPort: value as int);
        break;
      case 'appendHttpProxy':
        newSettings = currentSettings.copyWith(appendHttpProxy: value as bool);
        break;
      case 'allowAccess':
        newSettings = currentSettings.copyWith(allowAccess: value as bool);
        break;
      case 'connectionTestUrl':
        newSettings = currentSettings.copyWith(connectionTestUrl: value as String);
        break;
      case 'enableClashApi':
        newSettings = currentSettings.copyWith(enableClashApi: value as bool);
        break;
      case 'networkChangeResetConnections':
        newSettings = currentSettings.copyWith(networkChangeResetConnections: value as bool);
        break;
      case 'wakeResetConnections':
        newSettings = currentSettings.copyWith(wakeResetConnections: value as bool);
        break;
      case 'globalAllowInsecure':
        newSettings = currentSettings.copyWith(globalAllowInsecure: value as bool);
        break;
      case 'appTlsVersion':
        newSettings = currentSettings.copyWith(appTlsVersion: value as String);
        break;
      default:
        Logger.warning('未知的设置项: $key');
        return;
    }
    
    await updateSettings(newSettings);
  }
  
  /// 重置为默认值
  Future<void> resetToDefaults() async {
    await updateSettings(AppSettings());
  }
  
  /// 释放资源
  void dispose() {
    _settingsController.close();
  }
}
