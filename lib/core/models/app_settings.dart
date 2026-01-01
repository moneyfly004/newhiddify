import 'package:shared_preferences/shared_preferences.dart';
import 'kernel_type.dart';
import 'connection_mode.dart';

/// 应用设置模型
class AppSettings {
  // ==================== 通用设置 ====================
  
  /// 自动连接
  bool autoConnect;
  
  /// 主题颜色
  int themeColor;
  
  /// 夜间模式
  NightMode nightMode;
  
  /// 服务模式
  ServiceMode serviceMode;
  
  /// TUN 实现
  TunImplementation tunImplementation;
  
  /// MTU
  int mtu;
  
  /// 速度更新间隔（毫秒）
  int speedInterval;
  
  /// 启用流量统计
  bool enableTrafficStatistics;
  
  /// 显示直连速度
  bool showDirectSpeed;
  
  /// 在通知中显示组
  bool showGroupInNotification;
  
  /// 始终显示地址
  bool alwaysShowAddress;
  
  /// 计量网络
  bool meteredNetwork;
  
  /// 获取唤醒锁
  bool acquireWakeLock;
  
  /// 日志级别
  LogLevel logLevel;
  
  /// 全局自定义配置
  String? globalCustomConfig;
  
  // ==================== 路由设置 ====================
  
  /// 启用应用代理
  bool enableProxyApps;
  
  /// 代理的应用列表（包名）
  List<String> proxyAppList;
  
  /// 绕过模式
  BypassMode bypassMode;
  
  /// 绕过局域网
  bool bypassLan;
  
  /// 在核心中绕过局域网
  bool bypassLanInCore;
  
  /// 流量嗅探
  TrafficSniffing trafficSniffing;
  
  /// 解析目标
  bool resolveDestination;
  
  /// IPv6 模式
  Ipv6Mode ipv6Mode;
  
  /// 规则提供者
  RulesProvider rulesProvider;
  
  // ==================== DNS 设置 ====================
  
  /// 远程 DNS
  String remoteDns;
  
  /// 远程 DNS 域名策略
  DomainStrategy domainStrategyForRemote;
  
  /// 直连 DNS
  String directDns;
  
  /// 直连 DNS 域名策略
  DomainStrategy domainStrategyForDirect;
  
  /// 服务器 DNS 域名策略
  DomainStrategy domainStrategyForServer;
  
  /// 启用 DNS 路由
  bool enableDnsRouting;
  
  /// 启用 FakeDNS
  bool enableFakeDns;
  
  // ==================== 入站设置 ====================
  
  /// 混合端口
  int mixedPort;
  
  /// 追加 HTTP 代理
  bool appendHttpProxy;
  
  /// 允许访问
  bool allowAccess;
  
  // ==================== 其他设置 ====================
  
  /// 连接测试 URL
  String connectionTestUrl;
  
  /// 启用 Clash API
  bool enableClashApi;
  
  /// 网络变化重置连接
  bool networkChangeResetConnections;
  
  /// 唤醒重置连接
  bool wakeResetConnections;
  
  /// 全局允许不安全
  bool globalAllowInsecure;
  
  /// 请求时允许不安全
  bool allowInsecureOnRequest;
  
  /// 应用 TLS 版本
  String appTlsVersion;
  
  /// 显示底部栏
  bool showBottomBar;
  
  // ==================== 构造函数 ====================
  
  AppSettings({
    // 通用设置
    this.autoConnect = false,
    this.themeColor = 0xFF00FF00,
    this.nightMode = NightMode.auto,
    this.serviceMode = ServiceMode.vpn,
    this.tunImplementation = TunImplementation.system,
    this.mtu = 9000,
    this.speedInterval = 1000,
    this.enableTrafficStatistics = true,
    this.showDirectSpeed = true,
    this.showGroupInNotification = false,
    this.alwaysShowAddress = false,
    this.meteredNetwork = false,
    this.acquireWakeLock = false,
    this.logLevel = LogLevel.info,
    this.globalCustomConfig,
    
    // 路由设置
    this.enableProxyApps = false,
    this.proxyAppList = const [],
    this.bypassMode = BypassMode.individual,
    this.bypassLan = true,
    this.bypassLanInCore = false,
    this.trafficSniffing = TrafficSniffing.disabled,
    this.resolveDestination = false,
    this.ipv6Mode = Ipv6Mode.auto,
    this.rulesProvider = RulesProvider.auto,
    
    // DNS 设置
    this.remoteDns = 'https://dns.google/dns-query',
    this.domainStrategyForRemote = DomainStrategy.auto,
    this.directDns = 'https://223.5.5.5/dns-query',
    this.domainStrategyForDirect = DomainStrategy.auto,
    this.domainStrategyForServer = DomainStrategy.auto,
    this.enableDnsRouting = true,
    this.enableFakeDns = true,
    
    // 入站设置
    this.mixedPort = 7890,
    this.appendHttpProxy = false,
    this.allowAccess = false,
    
    // 其他设置
    this.connectionTestUrl = 'http://cp.cloudflare.com/',
    this.enableClashApi = false,
    this.networkChangeResetConnections = true,
    this.wakeResetConnections = false,
    this.globalAllowInsecure = false,
    this.allowInsecureOnRequest = false,
    this.appTlsVersion = '1.2',
    this.showBottomBar = true,
  });
  
  // ==================== 序列化 ====================
  
  /// 从 SharedPreferences 加载
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    return AppSettings(
      // 通用设置
      autoConnect: prefs.getBool('autoConnect') ?? false,
      themeColor: prefs.getInt('themeColor') ?? 0xFF00FF00,
      nightMode: NightMode.values[prefs.getInt('nightMode') ?? 0],
      // 默认使用 VPN 模式（索引 0 = vpn）
      serviceMode: ServiceMode.values[prefs.getInt('serviceMode') ?? ServiceMode.vpn.index],
      tunImplementation: TunImplementation.values[prefs.getInt('tunImplementation') ?? 0],
      mtu: prefs.getInt('mtu') ?? 9000,
      speedInterval: prefs.getInt('speedInterval') ?? 1000,
      enableTrafficStatistics: prefs.getBool('enableTrafficStatistics') ?? true,
      showDirectSpeed: prefs.getBool('showDirectSpeed') ?? true,
      showGroupInNotification: prefs.getBool('showGroupInNotification') ?? false,
      alwaysShowAddress: prefs.getBool('alwaysShowAddress') ?? false,
      meteredNetwork: prefs.getBool('meteredNetwork') ?? false,
      acquireWakeLock: prefs.getBool('acquireWakeLock') ?? false,
      logLevel: LogLevel.values[prefs.getInt('logLevel') ?? 2],
      globalCustomConfig: prefs.getString('globalCustomConfig'),
      
      // 路由设置
      enableProxyApps: prefs.getBool('enableProxyApps') ?? false,
      proxyAppList: prefs.getStringList('proxyAppList') ?? [],
      bypassMode: BypassMode.values[prefs.getInt('bypassMode') ?? 0],
      bypassLan: prefs.getBool('bypassLan') ?? true,
      bypassLanInCore: prefs.getBool('bypassLanInCore') ?? false,
      trafficSniffing: TrafficSniffing.values[prefs.getInt('trafficSniffing') ?? 0],
      resolveDestination: prefs.getBool('resolveDestination') ?? false,
      ipv6Mode: Ipv6Mode.values[prefs.getInt('ipv6Mode') ?? 0],
      rulesProvider: RulesProvider.values[prefs.getInt('rulesProvider') ?? 0],
      
      // DNS 设置
      remoteDns: prefs.getString('remoteDns') ?? 'https://dns.google/dns-query',
      domainStrategyForRemote: DomainStrategy.values[prefs.getInt('domainStrategyForRemote') ?? 0],
      directDns: prefs.getString('directDns') ?? 'https://223.5.5.5/dns-query',
      domainStrategyForDirect: DomainStrategy.values[prefs.getInt('domainStrategyForDirect') ?? 0],
      domainStrategyForServer: DomainStrategy.values[prefs.getInt('domainStrategyForServer') ?? 0],
      enableDnsRouting: prefs.getBool('enableDnsRouting') ?? true,
      enableFakeDns: prefs.getBool('enableFakeDns') ?? true,
      
      // 入站设置
      mixedPort: prefs.getInt('mixedPort') ?? 7890,
      appendHttpProxy: prefs.getBool('appendHttpProxy') ?? false,
      allowAccess: prefs.getBool('allowAccess') ?? false,
      
      // 其他设置
      connectionTestUrl: prefs.getString('connectionTestUrl') ?? 'http://cp.cloudflare.com/',
      enableClashApi: prefs.getBool('enableClashApi') ?? false,
      networkChangeResetConnections: prefs.getBool('networkChangeResetConnections') ?? true,
      wakeResetConnections: prefs.getBool('wakeResetConnections') ?? false,
      globalAllowInsecure: prefs.getBool('globalAllowInsecure') ?? false,
      allowInsecureOnRequest: prefs.getBool('allowInsecureOnRequest') ?? false,
      appTlsVersion: prefs.getString('appTlsVersion') ?? '1.2',
      showBottomBar: prefs.getBool('showBottomBar') ?? true,
    );
  }
  
  /// 保存到 SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 通用设置
    await prefs.setBool('autoConnect', autoConnect);
    await prefs.setInt('themeColor', themeColor);
    await prefs.setInt('nightMode', nightMode.index);
    await prefs.setInt('serviceMode', serviceMode.index);
    await prefs.setInt('tunImplementation', tunImplementation.index);
    await prefs.setInt('mtu', mtu);
    await prefs.setInt('speedInterval', speedInterval);
    await prefs.setBool('enableTrafficStatistics', enableTrafficStatistics);
    await prefs.setBool('showDirectSpeed', showDirectSpeed);
    await prefs.setBool('showGroupInNotification', showGroupInNotification);
    await prefs.setBool('alwaysShowAddress', alwaysShowAddress);
    await prefs.setBool('meteredNetwork', meteredNetwork);
    await prefs.setBool('acquireWakeLock', acquireWakeLock);
    await prefs.setInt('logLevel', logLevel.index);
    if (globalCustomConfig != null) {
      await prefs.setString('globalCustomConfig', globalCustomConfig!);
    }
    
    // 路由设置
    await prefs.setBool('enableProxyApps', enableProxyApps);
    await prefs.setStringList('proxyAppList', proxyAppList);
    await prefs.setInt('bypassMode', bypassMode.index);
    await prefs.setBool('bypassLan', bypassLan);
    await prefs.setBool('bypassLanInCore', bypassLanInCore);
    await prefs.setInt('trafficSniffing', trafficSniffing.index);
    await prefs.setBool('resolveDestination', resolveDestination);
    await prefs.setInt('ipv6Mode', ipv6Mode.index);
    await prefs.setInt('rulesProvider', rulesProvider.index);
    
    // DNS 设置
    await prefs.setString('remoteDns', remoteDns);
    await prefs.setInt('domainStrategyForRemote', domainStrategyForRemote.index);
    await prefs.setString('directDns', directDns);
    await prefs.setInt('domainStrategyForDirect', domainStrategyForDirect.index);
    await prefs.setInt('domainStrategyForServer', domainStrategyForServer.index);
    await prefs.setBool('enableDnsRouting', enableDnsRouting);
    await prefs.setBool('enableFakeDns', enableFakeDns);
    
    // 入站设置
    await prefs.setInt('mixedPort', mixedPort);
    await prefs.setBool('appendHttpProxy', appendHttpProxy);
    await prefs.setBool('allowAccess', allowAccess);
    
    // 其他设置
    await prefs.setString('connectionTestUrl', connectionTestUrl);
    await prefs.setBool('enableClashApi', enableClashApi);
    await prefs.setBool('networkChangeResetConnections', networkChangeResetConnections);
    await prefs.setBool('wakeResetConnections', wakeResetConnections);
    await prefs.setBool('globalAllowInsecure', globalAllowInsecure);
    await prefs.setBool('allowInsecureOnRequest', allowInsecureOnRequest);
    await prefs.setString('appTlsVersion', appTlsVersion);
    await prefs.setBool('showBottomBar', showBottomBar);
  }
  
  /// 复制
  AppSettings copyWith({
    bool? autoConnect,
    int? themeColor,
    NightMode? nightMode,
    ServiceMode? serviceMode,
    TunImplementation? tunImplementation,
    int? mtu,
    int? speedInterval,
    bool? enableTrafficStatistics,
    bool? showDirectSpeed,
    bool? showGroupInNotification,
    bool? alwaysShowAddress,
    bool? meteredNetwork,
    bool? acquireWakeLock,
    LogLevel? logLevel,
    String? globalCustomConfig,
    bool? enableProxyApps,
    List<String>? proxyAppList,
    BypassMode? bypassMode,
    bool? bypassLan,
    bool? bypassLanInCore,
    TrafficSniffing? trafficSniffing,
    bool? resolveDestination,
    Ipv6Mode? ipv6Mode,
    RulesProvider? rulesProvider,
    String? remoteDns,
    DomainStrategy? domainStrategyForRemote,
    String? directDns,
    DomainStrategy? domainStrategyForDirect,
    DomainStrategy? domainStrategyForServer,
    bool? enableDnsRouting,
    bool? enableFakeDns,
    int? mixedPort,
    bool? appendHttpProxy,
    bool? allowAccess,
    String? connectionTestUrl,
    bool? enableClashApi,
    bool? networkChangeResetConnections,
    bool? wakeResetConnections,
    bool? globalAllowInsecure,
    bool? allowInsecureOnRequest,
    String? appTlsVersion,
    bool? showBottomBar,
  }) {
    return AppSettings(
      autoConnect: autoConnect ?? this.autoConnect,
      themeColor: themeColor ?? this.themeColor,
      nightMode: nightMode ?? this.nightMode,
      serviceMode: serviceMode ?? this.serviceMode,
      tunImplementation: tunImplementation ?? this.tunImplementation,
      mtu: mtu ?? this.mtu,
      speedInterval: speedInterval ?? this.speedInterval,
      enableTrafficStatistics: enableTrafficStatistics ?? this.enableTrafficStatistics,
      showDirectSpeed: showDirectSpeed ?? this.showDirectSpeed,
      showGroupInNotification: showGroupInNotification ?? this.showGroupInNotification,
      alwaysShowAddress: alwaysShowAddress ?? this.alwaysShowAddress,
      meteredNetwork: meteredNetwork ?? this.meteredNetwork,
      acquireWakeLock: acquireWakeLock ?? this.acquireWakeLock,
      logLevel: logLevel ?? this.logLevel,
      globalCustomConfig: globalCustomConfig ?? this.globalCustomConfig,
      enableProxyApps: enableProxyApps ?? this.enableProxyApps,
      proxyAppList: proxyAppList ?? this.proxyAppList,
      bypassMode: bypassMode ?? this.bypassMode,
      bypassLan: bypassLan ?? this.bypassLan,
      bypassLanInCore: bypassLanInCore ?? this.bypassLanInCore,
      trafficSniffing: trafficSniffing ?? this.trafficSniffing,
      resolveDestination: resolveDestination ?? this.resolveDestination,
      ipv6Mode: ipv6Mode ?? this.ipv6Mode,
      rulesProvider: rulesProvider ?? this.rulesProvider,
      remoteDns: remoteDns ?? this.remoteDns,
      domainStrategyForRemote: domainStrategyForRemote ?? this.domainStrategyForRemote,
      directDns: directDns ?? this.directDns,
      domainStrategyForDirect: domainStrategyForDirect ?? this.domainStrategyForDirect,
      domainStrategyForServer: domainStrategyForServer ?? this.domainStrategyForServer,
      enableDnsRouting: enableDnsRouting ?? this.enableDnsRouting,
      enableFakeDns: enableFakeDns ?? this.enableFakeDns,
      mixedPort: mixedPort ?? this.mixedPort,
      appendHttpProxy: appendHttpProxy ?? this.appendHttpProxy,
      allowAccess: allowAccess ?? this.allowAccess,
      connectionTestUrl: connectionTestUrl ?? this.connectionTestUrl,
      enableClashApi: enableClashApi ?? this.enableClashApi,
      networkChangeResetConnections: networkChangeResetConnections ?? this.networkChangeResetConnections,
      wakeResetConnections: wakeResetConnections ?? this.wakeResetConnections,
      globalAllowInsecure: globalAllowInsecure ?? this.globalAllowInsecure,
      allowInsecureOnRequest: allowInsecureOnRequest ?? this.allowInsecureOnRequest,
      appTlsVersion: appTlsVersion ?? this.appTlsVersion,
      showBottomBar: showBottomBar ?? this.showBottomBar,
    );
  }
}

// ==================== 枚举类型 ====================

/// 夜间模式
enum NightMode {
  auto,
  light,
  dark,
  system,
}

/// 服务模式
enum ServiceMode {
  vpn,
  proxy,
}

/// TUN 实现
enum TunImplementation {
  system,
  gvisor,
  mixed,
}

/// 日志级别
enum LogLevel {
  trace,
  debug,
  info,
  warn,
  error,
}

/// 绕过模式
enum BypassMode {
  individual,
  whitelist,
  blacklist,
}

/// 流量嗅探
enum TrafficSniffing {
  disabled,
  http,
  tls,
}

/// IPv6 模式
enum Ipv6Mode {
  auto,
  enabled,
  disabled,
  prefer,
}

/// 规则提供者
enum RulesProvider {
  auto,
  local,
  remote,
  custom,
}

/// 域名策略
enum DomainStrategy {
  auto,
  ipv4Only,
  ipv6Only,
  preferIpv4,
  preferIpv6,
}

