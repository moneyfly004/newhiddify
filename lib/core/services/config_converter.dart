import 'dart:convert';
import 'package:yaml/yaml.dart' as yaml;
import 'protocol_converter.dart';

/// 配置转换器 - 处理不同订阅格式之间的转换
class ConfigConverter {
  /// 标准化节点格式
  static Map<String, dynamic> normalizeNode(dynamic node) {
    // 根据不同的输入格式，转换为标准格式
    if (node is Map) {
      // 转换为 Map<String, dynamic>
      final nodeMap = Map<String, dynamic>.from(node.map((k, v) => MapEntry(k.toString(), v)));
      // 处理 Clash 格式
      if (nodeMap.containsKey('name') && nodeMap.containsKey('type')) {
        return _fromClashNode(nodeMap);
      }
      // 处理 Sing-box 格式
      if (nodeMap.containsKey('tag') && nodeMap.containsKey('type')) {
        return _fromSingboxNode(nodeMap);
      }
    }
    return {};
  }

  /// 从 Clash 节点转换为标准格式
  static Map<String, dynamic> _fromClashNode(Map<String, dynamic> clashNode) {
    return {
      'name': clashNode['name'] ?? '',
      'type': clashNode['type'] ?? '',
      'server': clashNode['server'] ?? '',
      'port': clashNode['port'] ?? 0,
      'protocol': clashNode['type'] ?? '',
      'uuid': clashNode['uuid'] ?? clashNode['password'] ?? '',
      'password': clashNode['password'] ?? '',
      'cipher': clashNode['cipher'] ?? 'auto',
      'network': clashNode['network'] ?? 'tcp',
      'ws-path': clashNode['ws-path'] ?? clashNode['ws_path'] ?? '',
      'ws-headers': clashNode['ws-headers'] ?? clashNode['ws_headers'] ?? {},
      'tls': clashNode['tls'] ?? false,
      'sni': clashNode['sni'] ?? clashNode['servername'] ?? '',
    };
  }

  /// 从 Sing-box 节点转换为标准格式
  static Map<String, dynamic> _fromSingboxNode(Map<String, dynamic> singboxNode) {
    return {
      'name': singboxNode['tag'] ?? '',
      'type': singboxNode['type'] ?? '',
      'server': _extractServer(singboxNode),
      'port': _extractPort(singboxNode),
      'protocol': singboxNode['type'] ?? '',
      'uuid': _extractUUID(singboxNode),
      'password': _extractPassword(singboxNode),
    };
  }

  /// 提取服务器地址
  static String _extractServer(Map<String, dynamic> node) {
    if (node.containsKey('server')) return node['server'] as String;
    if (node.containsKey('address')) return node['address'] as String;
    return '';
  }

  /// 提取端口
  static int _extractPort(Map<String, dynamic> node) {
    if (node.containsKey('port')) return node['port'] as int;
    if (node.containsKey('server_port')) return node['server_port'] as int;
    return 0;
  }

  /// 提取 UUID
  static String _extractUUID(Map<String, dynamic> node) {
    if (node.containsKey('uuid')) return node['uuid'] as String;
    if (node.containsKey('user_id')) return node['user_id'] as String;
    return '';
  }

  /// 提取密码
  static String _extractPassword(Map<String, dynamic> node) {
    if (node.containsKey('password')) return node['password'] as String;
    return '';
  }

  /// Clash YAML 转换为 Sing-box JSON
  static Map<String, dynamic> clashToSingbox(String clashYaml) {
    try {
      final yamlDoc = yaml.loadYaml(clashYaml);
      final clashConfig = yamlDoc as Map;

      // 提取节点
      final proxies = clashConfig['proxies'] as List? ?? [];
      final nodes = proxies.map((p) => _clashNodeToSingbox(p)).toList();

      // 构建 Sing-box 配置
      return {
        'log': {
          'level': 'info',
        },
        'dns': {
          'servers': [
            {'address': '223.5.5.5'},
            {'address': '8.8.8.8'},
          ],
        },
        'inbounds': [
          {
            'type': 'mixed',
            'listen': '127.0.0.1',
            'listen_port': 7890,
          },
        ],
        'outbounds': nodes,
        'route': {
          'rules': [],
        },
      };
    } catch (e) {
      throw Exception('Clash 配置转换失败: $e');
    }
  }

  /// Clash 节点转换为 Sing-box 节点
  static Map<String, dynamic> _clashNodeToSingbox(Map<String, dynamic> clashNode) {
    // 使用协议转换器
    return ProtocolConverter.clashToSingbox(clashNode);
  }

  /// Sing-box JSON 转换为 Clash YAML
  static String singboxToClash(Map<String, dynamic> singboxConfig) {
    try {
      final outbounds = singboxConfig['outbounds'] as List? ?? [];
      final proxies = outbounds.map((o) => _singboxNodeToClash(o)).toList();

      final clashConfig = {
        'port': 7890,
        'socks-port': 7891,
        'allow-lan': false,
        'mode': 'rule',
        'log-level': 'info',
        'external-controller': '127.0.0.1:9090',
        'proxies': proxies,
        'proxy-groups': [
          {
            'name': '自动选择',
            'type': 'select',
            'proxies': proxies.map((p) => p['name']).toList(),
          },
        ],
        'rules': [],
      };

      // 转换为 YAML
      return _mapToYaml(clashConfig);
    } catch (e) {
      throw Exception('Sing-box 配置转换失败: $e');
    }
  }

  /// Sing-box 节点转换为 Clash 节点
  static Map<String, dynamic> _singboxNodeToClash(Map<String, dynamic> singboxNode) {
    // 使用协议转换器
    return ProtocolConverter.singboxToClash(singboxNode);
  }

  /// Map 转换为 YAML 字符串
  static String _mapToYaml(Map<String, dynamic> map) {
    // 简单的 YAML 转换（可以使用 yaml 包的 toYaml）
    final buffer = StringBuffer();
    _writeYamlValue(buffer, map, 0);
    return buffer.toString();
  }

  static void _writeYamlValue(StringBuffer buffer, dynamic value, int indent) {
    final indentStr = '  ' * indent;
    if (value is Map) {
      value.forEach((key, val) {
        buffer.writeln('$indentStr$key: ${_yamlValue(val, indent + 1)}');
      });
    } else if (value is List) {
      for (var item in value) {
        buffer.writeln('$indentStr- ${_yamlValue(item, indent + 1)}');
      }
    }
  }

  static String _yamlValue(dynamic value, int indent) {
    if (value is String) {
      return value.contains(' ') ? '"$value"' : value;
    } else if (value is Map || value is List) {
      final buffer = StringBuffer();
      _writeYamlValue(buffer, value, indent);
      return '\n$buffer';
    }
    return value.toString();
  }

  /// 检测配置格式
  static ConfigFormat detectFormat(String config) {
    try {
      // 尝试解析为 JSON
      final json = jsonDecode(config);
      if (json is Map && json.containsKey('outbounds')) {
        return ConfigFormat.singbox;
      }
      if (json is Map && json.containsKey('proxies')) {
        return ConfigFormat.clash;
      }
    } catch (e) {
      // 不是 JSON，尝试 YAML
      try {
        final yamlDoc = yaml.loadYaml(config);
        if (yamlDoc is Map && yamlDoc.containsKey('proxies')) {
          return ConfigFormat.clash;
        }
      } catch (e) {
        // 可能是 Base64 编码
        try {
          final decoded = utf8.decode(base64Decode(config));
          return detectFormat(decoded);
        } catch (e) {
          return ConfigFormat.unknown;
        }
      }
    }
    return ConfigFormat.unknown;
  }

  /// 解析订阅内容（支持多种格式）
  static List<Map<String, dynamic>> parseSubscription(String content) {
    final format = detectFormat(content);
    
    switch (format) {
      case ConfigFormat.clash:
        return _parseClash(content);
      case ConfigFormat.singbox:
        return _parseSingbox(content);
      case ConfigFormat.unknown:
        // 尝试 Base64 解码
        try {
          final decoded = utf8.decode(base64Decode(content));
          return parseSubscription(decoded);
        } catch (e) {
          throw Exception('无法解析订阅格式');
        }
      default:
        throw Exception('不支持的订阅格式');
    }
  }

  /// 解析 Clash 配置
  static List<Map<String, dynamic>> _parseClash(String yamlContent) {
    final yamlDoc = yaml.loadYaml(yamlContent);
    final config = yamlDoc as Map;
    final proxies = config['proxies'] as List? ?? [];
    return proxies.map((p) => (p as Map).cast<String, dynamic>()).toList();
  }

  /// 解析 Sing-box 配置
  static List<Map<String, dynamic>> _parseSingbox(String jsonContent) {
    final json = jsonDecode(jsonContent) as Map<String, dynamic>;
    final outbounds = json['outbounds'] as List? ?? [];
    return outbounds.map((o) => o as Map<String, dynamic>).toList();
  }
}

/// 配置格式枚举
enum ConfigFormat {
  clash,
  singbox,
  v2ray,
  unknown,
}

