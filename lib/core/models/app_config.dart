import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'kernel_type.dart';

part 'app_config.g.dart';

/// 应用配置模型
@JsonSerializable()
class AppConfig extends Equatable {
  final KernelType defaultKernel;
  final bool autoConnect;
  final bool autoTestSpeed;
  final int speedTestInterval; // 秒
  final String theme;
  final ProxyRules rules;

  const AppConfig({
    this.defaultKernel = KernelType.singbox,
    this.autoConnect = false,
    this.autoTestSpeed = false,
    this.speedTestInterval = 3600,
    this.theme = 'system',
    required this.rules,
  });

  factory AppConfig.defaultConfig() {
    return AppConfig(
      defaultKernel: KernelType.singbox,
      autoConnect: false,
      autoTestSpeed: false,
      speedTestInterval: 3600,
      theme: 'system',
      rules: ProxyRules.defaultRules(),
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  AppConfig copyWith({
    KernelType? defaultKernel,
    bool? autoConnect,
    bool? autoTestSpeed,
    int? speedTestInterval,
    String? theme,
    ProxyRules? rules,
  }) {
    return AppConfig(
      defaultKernel: defaultKernel ?? this.defaultKernel,
      autoConnect: autoConnect ?? this.autoConnect,
      autoTestSpeed: autoTestSpeed ?? this.autoTestSpeed,
      speedTestInterval: speedTestInterval ?? this.speedTestInterval,
      theme: theme ?? this.theme,
      rules: rules ?? this.rules,
    );
  }

  @override
  List<Object?> get props => [
        defaultKernel,
        autoConnect,
        autoTestSpeed,
        speedTestInterval,
        theme,
        rules,
      ];
}

/// 代理规则配置
@JsonSerializable()
class ProxyRules extends Equatable {
  final List<String> bypassRules;
  final List<String> proxyRules;
  final String dnsServer;
  final bool sniffing;

  const ProxyRules({
    this.bypassRules = const [],
    this.proxyRules = const [],
    this.dnsServer = '8.8.8.8',
    this.sniffing = true,
  });

  factory ProxyRules.defaultRules() {
    return const ProxyRules(
      bypassRules: [
        'localhost',
        '127.0.0.1',
        '192.168.0.0/16',
        '10.0.0.0/8',
      ],
      proxyRules: [],
      dnsServer: '8.8.8.8',
      sniffing: true,
    );
  }

  factory ProxyRules.fromJson(Map<String, dynamic> json) =>
      _$ProxyRulesFromJson(json);

  Map<String, dynamic> toJson() => _$ProxyRulesToJson(this);

  @override
  List<Object?> get props => [bypassRules, proxyRules, dnsServer, sniffing];
}

