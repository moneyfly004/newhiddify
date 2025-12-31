// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
      defaultKernel:
          $enumDecodeNullable(_$KernelTypeEnumMap, json['defaultKernel']) ??
              KernelType.singbox,
      autoConnect: json['autoConnect'] as bool? ?? false,
      autoTestSpeed: json['autoTestSpeed'] as bool? ?? false,
      speedTestInterval: (json['speedTestInterval'] as num?)?.toInt() ?? 3600,
      theme: json['theme'] as String? ?? 'system',
      rules: ProxyRules.fromJson(json['rules'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'defaultKernel': _$KernelTypeEnumMap[instance.defaultKernel]!,
      'autoConnect': instance.autoConnect,
      'autoTestSpeed': instance.autoTestSpeed,
      'speedTestInterval': instance.speedTestInterval,
      'theme': instance.theme,
      'rules': instance.rules,
    };

const _$KernelTypeEnumMap = {
  KernelType.singbox: 'singbox',
  KernelType.mihomo: 'mihomo',
};

ProxyRules _$ProxyRulesFromJson(Map<String, dynamic> json) => ProxyRules(
      bypassRules: (json['bypassRules'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      proxyRules: (json['proxyRules'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      dnsServer: json['dnsServer'] as String? ?? '8.8.8.8',
      sniffing: json['sniffing'] as bool? ?? true,
    );

Map<String, dynamic> _$ProxyRulesToJson(ProxyRules instance) =>
    <String, dynamic>{
      'bypassRules': instance.bypassRules,
      'proxyRules': instance.proxyRules,
      'dnsServer': instance.dnsServer,
      'sniffing': instance.sniffing,
    };
