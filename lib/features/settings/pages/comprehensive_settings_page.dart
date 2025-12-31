import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../ui/theme/cyberpunk_theme.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/models/auth_state.dart';
import 'dart:async';
import '../widgets/settings_section.dart';
import '../widgets/settings_switch_tile.dart';
import '../widgets/settings_menu_tile.dart';
import '../widgets/settings_text_field_tile.dart';
import '../widgets/app_proxy_selector_page.dart';
import '../widgets/log_viewer_page.dart';
import '../widgets/traffic_stats_page.dart';

/// 完整设置页面（参考 NekoBox）
class ComprehensiveSettingsPage extends StatefulWidget {
  const ComprehensiveSettingsPage({super.key});

  @override
  State<ComprehensiveSettingsPage> createState() => _ComprehensiveSettingsPageState();
}

class _ComprehensiveSettingsPageState extends State<ComprehensiveSettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  AppSettings? _settings;
  StreamSubscription<AppSettings>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _settingsSubscription = _settingsService.settingsStream.listen((settings) {
      if (mounted) {
        setState(() => _settings = settings);
      }
    });
  }

  Future<void> _loadSettings() async {
    await _settingsService.initialize();
    if (mounted) {
      setState(() => _settings = _settingsService.settings);
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _settingsService.resetToDefaults(),
            tooltip: '重置为默认值',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 通用设置
          SettingsSection(
            title: '通用设置',
            icon: Icons.settings,
            children: [
              SettingsSwitchTile(
                title: '自动连接',
                subtitle: '启动时自动连接',
                value: _settings!.autoConnect,
                onChanged: (value) => _settingsService.update('autoConnect', value),
              ),
              SettingsMenuTile<NightMode>(
                title: '夜间模式',
                value: _settings!.nightMode,
                options: NightMode.values,
                getLabel: (mode) {
                  switch (mode) {
                    case NightMode.auto:
                      return '自动';
                    case NightMode.light:
                      return '浅色';
                    case NightMode.dark:
                      return '深色';
                    case NightMode.system:
                      return '跟随系统';
                  }
                },
                onChanged: (value) => _settingsService.update('nightMode', value),
              ),
              SettingsMenuTile<ServiceMode>(
                title: '服务模式',
                value: _settings!.serviceMode,
                options: ServiceMode.values,
                getLabel: (mode) => mode == ServiceMode.vpn ? 'VPN' : '代理',
                onChanged: (value) => _settingsService.update('serviceMode', value),
              ),
              SettingsMenuTile<TunImplementation>(
                title: 'TUN 实现',
                value: _settings!.tunImplementation,
                options: TunImplementation.values,
                getLabel: (impl) {
                  switch (impl) {
                    case TunImplementation.system:
                      return '系统';
                    case TunImplementation.gvisor:
                      return 'gVisor';
                    case TunImplementation.mixed:
                      return '混合';
                  }
                },
                onChanged: (value) => _settingsService.update('tunImplementation', value),
              ),
              SettingsTextFieldTile(
                title: 'MTU',
                value: _settings!.mtu.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final mtu = int.tryParse(value) ?? 9000;
                  _settingsService.update('mtu', mtu);
                },
              ),
              SettingsTextFieldTile(
                title: '速度更新间隔（毫秒）',
                value: _settings!.speedInterval.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final interval = int.tryParse(value) ?? 1000;
                  _settingsService.update('speedInterval', interval);
                },
              ),
              SettingsSwitchTile(
                title: '启用流量统计',
                subtitle: '统计代理流量使用情况',
                value: _settings!.enableTrafficStatistics,
                onChanged: (value) => _settingsService.update('enableTrafficStatistics', value),
              ),
              SettingsSwitchTile(
                title: '显示直连速度',
                subtitle: '在通知中显示直连速度',
                value: _settings!.showDirectSpeed,
                onChanged: (value) => _settingsService.update('showDirectSpeed', value),
              ),
              SettingsSwitchTile(
                title: '始终显示地址',
                subtitle: '始终显示服务器地址',
                value: _settings!.alwaysShowAddress,
                onChanged: (value) => _settingsService.update('alwaysShowAddress', value),
              ),
              SettingsSwitchTile(
                title: '计量网络',
                subtitle: '允许在计量网络上使用',
                value: _settings!.meteredNetwork,
                onChanged: (value) => _settingsService.update('meteredNetwork', value),
              ),
              SettingsSwitchTile(
                title: '获取唤醒锁',
                subtitle: '保持 CPU 唤醒',
                value: _settings!.acquireWakeLock,
                onChanged: (value) => _settingsService.update('acquireWakeLock', value),
              ),
              SettingsMenuTile<LogLevel>(
                title: '日志级别',
                value: _settings!.logLevel,
                options: LogLevel.values,
                getLabel: (level) {
                  switch (level) {
                    case LogLevel.trace:
                      return '跟踪';
                    case LogLevel.debug:
                      return '调试';
                    case LogLevel.info:
                      return '信息';
                    case LogLevel.warn:
                      return '警告';
                    case LogLevel.error:
                      return '错误';
                  }
                },
                onChanged: (value) => _settingsService.update('logLevel', value),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('查看日志'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogViewerPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 路由设置
          SettingsSection(
            title: '路由设置',
            icon: Icons.route,
            children: [
              SettingsSwitchTile(
                title: '启用应用代理',
                subtitle: '选择哪些应用走代理',
                value: _settings!.enableProxyApps,
                onChanged: (value) => _settingsService.update('enableProxyApps', value),
              ),
              if (_settings!.enableProxyApps)
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('选择应用'),
                  subtitle: Text('已选择 ${_settings!.proxyAppList.length} 个应用'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppProxySelectorPage(
                        selectedApps: _settings!.proxyAppList,
                        onAppsSelected: (apps) {
                          _settingsService.update('proxyAppList', apps);
                        },
                      ),
                    ),
                  ),
                ),
              SettingsSwitchTile(
                title: '绕过局域网',
                subtitle: '局域网流量不走代理',
                value: _settings!.bypassLan,
                onChanged: (value) => _settingsService.update('bypassLan', value),
              ),
              SettingsSwitchTile(
                title: '在核心中绕过局域网',
                subtitle: '在内核层面绕过局域网',
                value: _settings!.bypassLanInCore,
                onChanged: (value) => _settingsService.update('bypassLanInCore', value),
              ),
              SettingsMenuTile<TrafficSniffing>(
                title: '流量嗅探',
                value: _settings!.trafficSniffing,
                options: TrafficSniffing.values,
                getLabel: (sniffing) {
                  switch (sniffing) {
                    case TrafficSniffing.disabled:
                      return '禁用';
                    case TrafficSniffing.http:
                      return 'HTTP';
                    case TrafficSniffing.tls:
                      return 'TLS';
                  }
                },
                onChanged: (value) => _settingsService.update('trafficSniffing', value),
              ),
              SettingsSwitchTile(
                title: '解析目标',
                subtitle: '解析目标地址',
                value: _settings!.resolveDestination,
                onChanged: (value) => _settingsService.update('resolveDestination', value),
              ),
              SettingsMenuTile<Ipv6Mode>(
                title: 'IPv6 模式',
                value: _settings!.ipv6Mode,
                options: Ipv6Mode.values,
                getLabel: (mode) {
                  switch (mode) {
                    case Ipv6Mode.auto:
                      return '自动';
                    case Ipv6Mode.enabled:
                      return '启用';
                    case Ipv6Mode.disabled:
                      return '禁用';
                    case Ipv6Mode.prefer:
                      return '优先';
                  }
                },
                onChanged: (value) => _settingsService.update('ipv6Mode', value),
              ),
              SettingsMenuTile<RulesProvider>(
                title: '规则提供者',
                value: _settings!.rulesProvider,
                options: RulesProvider.values,
                getLabel: (provider) {
                  switch (provider) {
                    case RulesProvider.auto:
                      return '自动';
                    case RulesProvider.local:
                      return '本地';
                    case RulesProvider.remote:
                      return '远程';
                    case RulesProvider.custom:
                      return '自定义';
                  }
                },
                onChanged: (value) => _settingsService.update('rulesProvider', value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // DNS 设置
          SettingsSection(
            title: 'DNS 设置',
            icon: Icons.dns,
            children: [
              SettingsTextFieldTile(
                title: '远程 DNS',
                subtitle: '代理 DNS 服务器',
                value: _settings!.remoteDns,
                onChanged: (value) => _settingsService.update('remoteDns', value),
              ),
              SettingsMenuTile<DomainStrategy>(
                title: '远程 DNS 域名策略',
                value: _settings!.domainStrategyForRemote,
                options: DomainStrategy.values,
                getLabel: (strategy) => _getDomainStrategyLabel(strategy),
                onChanged: (value) => _settingsService.update('domainStrategyForRemote', value),
              ),
              SettingsTextFieldTile(
                title: '直连 DNS',
                subtitle: '直连 DNS 服务器',
                value: _settings!.directDns,
                onChanged: (value) => _settingsService.update('directDns', value),
              ),
              SettingsMenuTile<DomainStrategy>(
                title: '直连 DNS 域名策略',
                value: _settings!.domainStrategyForDirect,
                options: DomainStrategy.values,
                getLabel: (strategy) => _getDomainStrategyLabel(strategy),
                onChanged: (value) => _settingsService.update('domainStrategyForDirect', value),
              ),
              SettingsSwitchTile(
                title: '启用 DNS 路由',
                subtitle: '根据 DNS 结果路由流量',
                value: _settings!.enableDnsRouting,
                onChanged: (value) => _settingsService.update('enableDnsRouting', value),
              ),
              SettingsSwitchTile(
                title: '启用 FakeDNS',
                subtitle: '使用 FakeDNS 进行流量嗅探',
                value: _settings!.enableFakeDns,
                onChanged: (value) => _settingsService.update('enableFakeDns', value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 入站设置
          SettingsSection(
            title: '入站设置',
            icon: Icons.input,
            children: [
              SettingsTextFieldTile(
                title: '混合端口',
                subtitle: 'HTTP 和 SOCKS 代理端口',
                value: _settings!.mixedPort.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final port = int.tryParse(value) ?? 7890;
                  _settingsService.update('mixedPort', port);
                },
              ),
              SettingsSwitchTile(
                title: '追加 HTTP 代理',
                subtitle: '在配置中追加 HTTP 代理',
                value: _settings!.appendHttpProxy,
                onChanged: (value) => _settingsService.update('appendHttpProxy', value),
              ),
              SettingsSwitchTile(
                title: '允许访问',
                subtitle: '允许局域网访问',
                value: _settings!.allowAccess,
                onChanged: (value) => _settingsService.update('allowAccess', value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 其他设置
          SettingsSection(
            title: '其他设置',
            icon: Icons.more_horiz,
            children: [
              SettingsTextFieldTile(
                title: '连接测试 URL',
                subtitle: '用于测试连接',
                value: _settings!.connectionTestUrl,
                onChanged: (value) => _settingsService.update('connectionTestUrl', value),
              ),
              SettingsSwitchTile(
                title: '启用 Clash API',
                subtitle: '启用 Clash 兼容 API',
                value: _settings!.enableClashApi,
                onChanged: (value) => _settingsService.update('enableClashApi', value),
              ),
              SettingsSwitchTile(
                title: '网络变化重置连接',
                subtitle: '网络变化时重置连接',
                value: _settings!.networkChangeResetConnections,
                onChanged: (value) => _settingsService.update('networkChangeResetConnections', value),
              ),
              SettingsSwitchTile(
                title: '唤醒重置连接',
                subtitle: '设备唤醒时重置连接',
                value: _settings!.wakeResetConnections,
                onChanged: (value) => _settingsService.update('wakeResetConnections', value),
              ),
              SettingsSwitchTile(
                title: '全局允许不安全',
                subtitle: '全局允许不安全的 TLS 连接',
                value: _settings!.globalAllowInsecure,
                onChanged: (value) => _settingsService.update('globalAllowInsecure', value),
              ),
              SettingsMenuTile<String>(
                title: '应用 TLS 版本',
                value: _settings!.appTlsVersion,
                options: const ['1.0', '1.1', '1.2', '1.3'],
                getLabel: (version) => version,
                onChanged: (value) => _settingsService.update('appTlsVersion', value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 流量统计
          SettingsSection(
            title: '流量统计',
            icon: Icons.bar_chart,
            children: [
              ListTile(
                leading: const Icon(Icons.traffic),
                title: const Text('查看流量统计'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrafficStatsPage()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 账户设置
          SettingsSection(
            title: '账户',
            icon: Icons.person,
            children: [
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('用户名'),
                      subtitle: Text(state.user.username),
                    );
                  }
                  return const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('未登录'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () {
                  context.read<AuthCubit>().logout();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 关于
          SettingsSection(
            title: '关于',
            icon: Icons.info,
            children: [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('版本'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDomainStrategyLabel(DomainStrategy strategy) {
    switch (strategy) {
      case DomainStrategy.auto:
        return '自动';
      case DomainStrategy.ipv4Only:
        return '仅 IPv4';
      case DomainStrategy.ipv6Only:
        return '仅 IPv6';
      case DomainStrategy.preferIpv4:
        return '优先 IPv4';
      case DomainStrategy.preferIpv6:
        return '优先 IPv6';
    }
  }
}

