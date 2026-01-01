import 'dart:convert';
import 'package:yaml/yaml.dart' as yaml;
import '../models/kernel_type.dart';
import '../models/connection_mode.dart';
import '../../features/servers/models/subscription.dart';
import '../../features/servers/models/node.dart';
import 'config_converter.dart';
import 'rule_manager.dart';
import 'dns_manager.dart';
import 'yaml_generator.dart';

/// 内核配置生成器
class KernelConfigGenerator {
  /// 生成内核配置
  static Future<String> generateConfig({
    required KernelType kernelType,
    required Subscription subscription,
    required ConnectionMode mode,
    Node? selectedNode,
    String? rawConfig,
    bool? isVpnMode,
    bool? allowAccess,
    int? mixedPort,
    bool? bypassLan,
    List<String>? remoteDns,
    List<String>? directDns,
  }) async {
    // 如果有原始配置，先解析
    if (rawConfig != null) {
      return _processRawConfig(rawConfig, kernelType, mode, selectedNode);
    }

    // 否则根据内核类型生成
    switch (kernelType) {
      case KernelType.singbox:
        return _generateSingboxConfig(
          subscription,
          mode,
          selectedNode,
          isVpnMode: isVpnMode ?? true,
          allowAccess: allowAccess ?? false,
          mixedPort: mixedPort ?? 2080,
          bypassLan: bypassLan ?? true,
          remoteDns: remoteDns,
          directDns: directDns,
        );
      case KernelType.mihomo:
        return _generateClashConfig(subscription, mode, selectedNode);
    }
  }

  /// 处理原始配置
  static String _processRawConfig(
    String rawConfig,
    KernelType targetKernel,
    ConnectionMode mode,
    Node? selectedNode,
  ) {
    final format = ConfigConverter.detectFormat(rawConfig);

    // 如果格式匹配，直接使用
    if ((format == ConfigFormat.clash && targetKernel == KernelType.mihomo) ||
        (format == ConfigFormat.singbox && targetKernel == KernelType.singbox)) {
      return _applyModeAndNode(rawConfig, targetKernel, mode, selectedNode);
    }

    // 需要转换格式
    if (format == ConfigFormat.clash && targetKernel == KernelType.singbox) {
      final clashYaml = rawConfig;
      final singboxJson = ConfigConverter.clashToSingbox(clashYaml);
      return _applyModeAndNode(
        jsonEncode(singboxJson),
        targetKernel,
        mode,
        selectedNode,
      );
    }

    if (format == ConfigFormat.singbox && targetKernel == KernelType.mihomo) {
      final singboxJson = jsonDecode(rawConfig) as Map<String, dynamic>;
      final clashYaml = ConfigConverter.singboxToClash(singboxJson);
      return _applyModeAndNode(clashYaml, targetKernel, mode, selectedNode);
    }

    throw Exception('不支持的配置格式转换');
  }

  /// 应用模式和节点选择
  static String _applyModeAndNode(
    String config,
    KernelType kernelType,
    ConnectionMode mode,
    Node? selectedNode,
  ) {
    if (kernelType == KernelType.singbox) {
      return _applyModeAndNodeToSingbox(config, mode, selectedNode);
    } else {
      return _applyModeAndNodeToClash(config, mode, selectedNode);
    }
  }

  /// 应用模式和节点到 Sing-box 配置
  static String _applyModeAndNodeToSingbox(
    String config,
    ConnectionMode mode,
    Node? selectedNode,
  ) {
    try {
      final json = jsonDecode(config) as Map<String, dynamic>;
      
      // 应用模式
      if (mode == ConnectionMode.global) {
        json['route'] = {
          'rules': [],
          'final': 'proxy',
        };
      } else {
        // 获取规则并确保格式正确
        final rules = RuleManager.getSingboxRules(mode);
        json['route'] = {
          'rules': rules,
          'final': 'direct',
        };
      }

      // 应用节点选择（如果有）
      if (selectedNode != null && json.containsKey('outbounds')) {
        // 解析节点配置
        final nodeConfig = jsonDecode(selectedNode.config ?? '{}') as Map<String, dynamic>;
        
        // 转换为 Sing-box outbound 格式
        final outbound = _nodeConfigToSingboxOutbound(nodeConfig, selectedNode.name);
        
        // 替换或添加 outbound
        final outbounds = json['outbounds'] as List? ?? [];
        // 移除旧的 proxy outbound
        outbounds.removeWhere((o) => 
          o is Map && (o['tag'] == 'proxy' || o['tag'] == selectedNode.name)
        );
        // 添加新的 outbound
        outbounds.add(outbound);
        json['outbounds'] = outbounds;
      }

      return jsonEncode(json);
    } catch (e) {
      // 如果解析失败，返回原配置
      return config;
    }
  }

  /// 节点配置转换为 Sing-box outbound
  static Map<String, dynamic> _nodeConfigToSingboxOutbound(
    Map<String, dynamic> nodeConfig,
    String name,
  ) {
    final type = nodeConfig['type'] as String? ?? 'vmess';
    final outbound = <String, dynamic>{
      'type': type,
      'tag': 'proxy',
      'server': nodeConfig['server'],
      'server_port': nodeConfig['port'],
    };

    switch (type) {
      case 'vmess':
        outbound['uuid'] = nodeConfig['uuid'];
        outbound['security'] = nodeConfig['cipher'] ?? 'auto';
        outbound['alter_id'] = nodeConfig['alterId'] ?? 0;
        break;
      case 'vless':
        outbound['uuid'] = nodeConfig['uuid'];
        if (nodeConfig.containsKey('flow')) {
          outbound['flow'] = nodeConfig['flow'];
        }
        break;
      case 'trojan':
        outbound['password'] = nodeConfig['password'];
        break;
      case 'ss':
      case 'shadowsocks':
        outbound['method'] = nodeConfig['cipher'];
        outbound['password'] = nodeConfig['password'];
        break;
    }

    // 添加传输协议
    final network = nodeConfig['network'] as String? ?? 'tcp';
    if (network != 'tcp' && network.isNotEmpty) {
      final transport = <String, dynamic>{
        'type': network == 'ws' || network == 'websocket' ? 'ws' : 
                network == 'h2' || network == 'http' ? 'http' :
                network == 'grpc' ? 'grpc' : network,
      };
      
      switch (network) {
        case 'ws':
        case 'websocket':
          transport['path'] = nodeConfig['ws-path'] ?? nodeConfig['path'] ?? '/';
          final headers = <String, dynamic>{};
          if (nodeConfig.containsKey('ws-headers')) {
            final wsHeaders = nodeConfig['ws-headers'];
            if (wsHeaders is Map) {
              headers.addAll(Map<String, dynamic>.from(wsHeaders));
            }
          }
          if (nodeConfig.containsKey('host') && !headers.containsKey('Host')) {
            headers['Host'] = nodeConfig['host'];
          }
          if (headers.isNotEmpty) {
            transport['headers'] = headers;
          }
          break;
        case 'h2':
        case 'http':
          final h2Opts = nodeConfig['h2-opts'] as Map<String, dynamic>?;
          transport['host'] = h2Opts?['host'] ?? 
                              (nodeConfig.containsKey('host') ? [nodeConfig['host']] : []);
          transport['path'] = h2Opts?['path'] ?? nodeConfig['path'] ?? '/';
          break;
        case 'grpc':
          final grpcOpts = nodeConfig['grpc-opts'] as Map<String, dynamic>?;
          transport['service_name'] = grpcOpts?['grpc-service-name'] ?? 
                                       nodeConfig['path'] ?? '';
          break;
      }
      
      if (transport['type'] != 'tcp') {
        outbound['transport'] = transport;
      }
    }

    // 添加 TLS 配置
    if (nodeConfig['tls'] == true || nodeConfig['tls'] == 'tls') {
      final tlsConfig = <String, dynamic>{
        'enabled': true,
        'insecure': nodeConfig['skip-cert-verify'] ?? false,
      };
      
      if (nodeConfig.containsKey('sni') && nodeConfig['sni'] != null) {
        tlsConfig['server_name'] = nodeConfig['sni'];
      }
      
      if (nodeConfig.containsKey('alpn')) {
        final alpn = nodeConfig['alpn'];
        if (alpn is List) {
          tlsConfig['alpn'] = alpn;
        } else if (alpn is String) {
          tlsConfig['alpn'] = [alpn];
        }
      }

      // Reality 配置
      if (nodeConfig.containsKey('reality-opts')) {
        final realityOpts = nodeConfig['reality-opts'] as Map<String, dynamic>?;
        if (realityOpts != null) {
          tlsConfig['reality'] = {
            'enabled': true,
            'public_key': realityOpts['public-key'],
            'short_id': realityOpts['short-id'],
          };
        }
      }
      
      outbound['tls'] = tlsConfig;
    }

    return outbound;
  }

  /// 应用模式和节点到 Clash 配置
  static String _applyModeAndNodeToClash(
    String config,
    ConnectionMode mode,
    Node? selectedNode,
  ) {
    try {
      final yamlDoc = yaml.loadYaml(config);
      final clashConfig = yamlDoc as Map;
      
      // 应用模式
      clashConfig['mode'] = mode == ConnectionMode.global ? 'global' : 'rule';
      
      // 应用规则
      if (mode == ConnectionMode.rules) {
        clashConfig['rules'] = RuleManager.getClashRules(mode);
      } else {
        clashConfig['rules'] = [];
      }

      // 应用节点选择（如果有）
      if (selectedNode != null) {
        // 解析节点配置
        final nodeConfig = jsonDecode(selectedNode.config ?? '{}') as Map<String, dynamic>;
        
        // 转换为 Clash proxy 格式
        final proxy = _nodeConfigToClashProxy(nodeConfig, selectedNode.name);
        
        // 更新 proxies
        final proxies = clashConfig['proxies'] as List? ?? [];
        // 移除同名的 proxy
        proxies.removeWhere((p) => 
          p is Map && (p['name'] == selectedNode.name || p['name'] == 'proxy')
        );
        // 添加新的 proxy
        proxies.add(proxy);
        clashConfig['proxies'] = proxies;

        // 更新 proxy-groups
        if (clashConfig.containsKey('proxy-groups')) {
          final groups = clashConfig['proxy-groups'] as List;
          for (var group in groups) {
            if (group is Map) {
              final proxies = group['proxies'] as List? ?? [];
              if (!proxies.contains(selectedNode.name)) {
                proxies.insert(0, selectedNode.name);
              }
            }
          }
        }
      }

      // 转换回 YAML
      final clashConfigMap = Map<String, dynamic>.from(clashConfig.map((k, v) => MapEntry(k.toString(), v)));
      return YamlGenerator.mapToYaml(clashConfigMap);
    } catch (e) {
      return config;
    }
  }

  /// 节点配置转换为 Clash proxy
  static Map<String, dynamic> _nodeConfigToClashProxy(
    Map<String, dynamic> nodeConfig,
    String name,
  ) {
    final type = nodeConfig['type'] as String? ?? 'vmess';
    final proxy = <String, dynamic>{
      'name': name,
      'type': type,
      'server': nodeConfig['server'],
      'port': nodeConfig['port'],
    };

    switch (type) {
      case 'vmess':
        proxy['uuid'] = nodeConfig['uuid'];
        proxy['cipher'] = nodeConfig['cipher'] ?? 'auto';
        proxy['alterId'] = nodeConfig['alterId'] ?? 0;
        break;
      case 'vless':
        proxy['uuid'] = nodeConfig['uuid'];
        if (nodeConfig.containsKey('flow')) {
          proxy['flow'] = nodeConfig['flow'];
        }
        break;
      case 'trojan':
        proxy['password'] = nodeConfig['password'];
        break;
      case 'ss':
      case 'shadowsocks':
        proxy['cipher'] = nodeConfig['cipher'];
        proxy['password'] = nodeConfig['password'];
        break;
    }

    // 添加传输协议
    if (nodeConfig.containsKey('network') && nodeConfig['network'] != 'tcp') {
      final network = nodeConfig['network'] as String;
      proxy['network'] = network;
      
      switch (network) {
        case 'ws':
          proxy['ws-path'] = nodeConfig['ws-path'] ?? '/';
          if (nodeConfig.containsKey('ws-headers')) {
            proxy['ws-headers'] = nodeConfig['ws-headers'];
          }
          break;
        case 'h2':
          proxy['h2-opts'] = {
            'host': nodeConfig['h2-opts']?['host'] ?? [],
            'path': nodeConfig['h2-opts']?['path'] ?? '/',
          };
          break;
        case 'grpc':
          proxy['grpc-opts'] = {
            'grpc-service-name': nodeConfig['grpc-opts']?['grpc-service-name'] ?? '',
          };
          break;
      }
    }

    // 添加 TLS 配置
    if (nodeConfig['tls'] == true) {
      proxy['tls'] = true;
      if (nodeConfig.containsKey('sni')) {
        proxy['sni'] = nodeConfig['sni'];
      }
      if (nodeConfig['skip-cert-verify'] == true) {
        proxy['skip-cert-verify'] = true;
      }
      if (nodeConfig.containsKey('alpn')) {
        proxy['alpn'] = nodeConfig['alpn'];
      }

      // Reality 配置
      if (nodeConfig.containsKey('reality-opts')) {
        proxy['reality-opts'] = {
          'public-key': nodeConfig['reality-opts']?['public-key'],
          'short-id': nodeConfig['reality-opts']?['short-id'],
        };
      }
    }

    return proxy;
  }

  /// 生成 Sing-box 配置（参考 NekoBoxForAndroid）
  static String _generateSingboxConfig(
    Subscription subscription,
    ConnectionMode mode,
    Node? selectedNode, {
    bool isVpnMode = true,
    bool allowAccess = false,
    int mixedPort = 2080,
    bool bypassLan = true,
    List<String>? remoteDns,
    List<String>? directDns,
  }) {
    final inbounds = <Map<String, dynamic>>[];
    
    // VPN 模式：添加 TUN inbound（必须，用于创建 VPN 接口）
    if (isVpnMode) {
      inbounds.add({
        'type': 'tun',
        'tag': 'tun-in',
        'stack': 'mixed',
        'endpoint_independent_nat': true,
        'mtu': 1500,
        'domain_strategy': 'prefer_ipv4',
        'sniff': true,
        'sniff_override_destination': false,
        'inet4_address': ['172.19.0.1/28'],
        'auto_route': false,  // 禁用 auto_route，让 VPN Service 管理路由
        'strict_route': false,
      });
    }
    
    // 无论 VPN 还是代理模式，都添加 mixed inbound（外部端口）
    final bind = allowAccess ? '0.0.0.0' : '127.0.0.1';
    inbounds.add({
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': bind,
      'listen_port': mixedPort,
      'domain_strategy': 'prefer_ipv4',
      'sniff': true,
      'sniff_override_destination': false,
    });

    final config = {
      'log': {
        'level': 'info',
        'timestamp': true,
      },
      'dns': DnsManager.getSingboxDns(
        remoteDns: remoteDns ?? ['https://dns.google/dns-query'],
        directDns: directDns ?? ['https://223.5.5.5/dns-query'],
        enableFakeDns: false, // 暂时禁用 FakeDNS
        enableDnsRouting: true,
      ),
      'inbounds': inbounds,
      'outbounds': () {
        final outbounds = <Map<String, dynamic>>[
          {
            'type': 'direct',
            'tag': 'direct',
          },
          {
            'type': 'direct',
            'tag': 'bypass',
          },
          {
            'type': 'block',
            'tag': 'block',
          },
        ];
        if (selectedNode != null) {
          final proxyOutbound = _nodeToSingboxOutbound(selectedNode);
          // 确保 proxy outbound 的 tag 是 'proxy'（路由规则需要）
          proxyOutbound['tag'] = 'proxy';
          outbounds.add(proxyOutbound);
        }
        return outbounds;
      }(),
      'route': {
        'rules': _buildRouteRules(mode),
        'auto_detect_interface': true,
        // 规则模式：final 应该是 'proxy'，因为规则中最后一条是 {'outbound': 'proxy'}
        // 全局模式：final 应该是 'proxy'，所有流量走代理
        'final': 'proxy',
      },
    };

    return jsonEncode(config);
  }

  /// 构建路由规则（参考 NekoBoxForAndroid）
  static List<Map<String, dynamic>> _buildRouteRules(ConnectionMode mode) {
    final rules = <Map<String, dynamic>>[];
    
    // DNS hijack 规则（必须放在最前面）
    rules.add({
      'protocol': ['dns'],
      'action': 'hijack-dns',
    });
    rules.add({
      'port': [53],
      'action': 'hijack-dns',
    });
    
    // 添加其他规则
    rules.addAll(RuleManager.getSingboxRules(mode));
    
    return rules;
  }

  /// 节点转换为 Sing-box outbound
  static Map<String, dynamic> _nodeToSingboxOutbound(Node node) {
    try {
      final nodeConfig = jsonDecode(node.config ?? '{}') as Map<String, dynamic>;
      // 使用完整的节点配置转换方法
      return _nodeConfigToSingboxOutbound(nodeConfig, node.name);
    } catch (e) {
      // 如果转换失败，返回一个基本的 direct outbound
      return {
        'type': 'direct',
        'tag': 'proxy',
      };
    }
  }

  /// 生成 Clash 配置
  static String _generateClashConfig(
    Subscription subscription,
    ConnectionMode mode,
    Node? selectedNode,
  ) {
    final proxies = <Map<String, dynamic>>[];
    if (selectedNode != null) {
      proxies.add(_nodeToClashProxy(selectedNode));
    }

    final config = {
      'port': 7890,
      'socks-port': 7891,
      'allow-lan': false,
      'mode': mode == ConnectionMode.rules ? 'rule' : 'global',
      'log-level': 'info',
      'external-controller': '127.0.0.1:9090',
      'dns': DnsManager.getClashDns(),
      'proxies': proxies,
      'proxy-groups': [
        {
          'name': '🚀 节点选择',
          'type': 'select',
          'proxies': ['DIRECT', if (selectedNode != null) selectedNode.name],
        },
        {
          'name': '♻️ 自动选择',
          'type': 'url-test',
          'url': 'http://www.gstatic.com/generate_204',
          'interval': 300,
          'tolerance': 50,
          'proxies': [if (selectedNode != null) selectedNode.name],
        },
      ],
      'rules': RuleManager.getClashRules(mode),
    };

      return YamlGenerator.mapToYaml(config);
  }

  /// 节点转换为 Clash proxy
  static Map<String, dynamic> _nodeToClashProxy(Node node) {
    try {
      final nodeConfig = jsonDecode(node.config ?? '{}') as Map<String, dynamic>;
      return _nodeConfigToClashProxy(nodeConfig, node.name);
    } catch (e) {
      return {
        'name': node.name,
        'type': 'direct',
      };
    }
  }


  /// Map 转 YAML（简化版）
  static String _mapToYaml(Map<String, dynamic> map) {
    // 这里可以使用 yaml 包的 toYaml
    // 简化实现
    final buffer = StringBuffer();
    _writeYaml(buffer, map, 0);
    return buffer.toString();
  }

  static void _writeYaml(StringBuffer buffer, dynamic value, int indent) {
    final indentStr = '  ' * indent;
    if (value is Map) {
      value.forEach((key, val) {
        if (val is Map || val is List) {
          buffer.writeln('$indentStr$key:');
          _writeYaml(buffer, val, indent + 1);
        } else {
          buffer.writeln('$indentStr$key: $val');
        }
      });
    } else if (value is List) {
      for (var item in value) {
        if (item is Map) {
          buffer.writeln('$indentStr-');
          _writeYaml(buffer, item, indent + 1);
        } else {
          buffer.writeln('$indentStr- $item');
        }
      }
    }
  }
}

