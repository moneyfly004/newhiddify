import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';
import '../../features/servers/models/node.dart';

/// Base64 订阅解析器
class Base64SubscriptionParser {
  /// 解析 Base64 编码的订阅内容
  static List<Node> parseBase64Subscription(String base64Content) {
    try {
      debugPrint('[Base64Parser] 开始解析 Base64 订阅');
      debugPrint('[Base64Parser] Base64 内容长度: ${base64Content.length}');
      debugPrint('[Base64Parser] Base64 内容前100字符: ${base64Content.length > 100 ? base64Content.substring(0, 100) : base64Content}');
      
      // 解码 Base64
      final decoded = utf8.decode(base64Decode(base64Content));
      debugPrint('[Base64Parser] 解码后内容长度: ${decoded.length}');
      debugPrint('[Base64Parser] 解码后内容前200字符: ${decoded.length > 200 ? decoded.substring(0, 200) : decoded}');
      
      // 按行分割节点链接
      final lines = decoded.split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      debugPrint('[Base64Parser] 分割后行数: ${lines.length}');
      if (lines.isNotEmpty) {
        debugPrint('[Base64Parser] 第一行示例: ${lines.first.length > 100 ? lines.first.substring(0, 100) : lines.first}');
      }

      final nodes = <Node>[];

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        try {
          debugPrint('[Base64Parser] 解析第 ${i + 1} 行: ${line.substring(0, line.length > 50 ? 50 : line.length)}...');
          final node = _parseNodeLink(line);
          if (node != null) {
            // 过滤掉错误提示节点（地址是 baidu.com 的无效节点）
            if (node.config != null && node.config!.isNotEmpty) {
              try {
                final configJson = jsonDecode(node.config!) as Map<String, dynamic>;
                final server = configJson['server'] as String? ?? '';
                
                if (server == 'baidu.com' || server.isEmpty) {
                  debugPrint('[Base64Parser] 跳过错误提示节点: ${node.name} (server: $server)');
                  continue;
                }
              } catch (e) {
                debugPrint('[Base64Parser] 解析节点配置失败: $e');
                // 如果解析失败，仍然添加节点
              }
            }
            
            nodes.add(node);
            debugPrint('[Base64Parser] 成功解析节点: ${node.name} (${node.type})');
          } else {
            debugPrint('[Base64Parser] 节点解析返回 null');
          }
        } catch (e, stackTrace) {
          debugPrint('[Base64Parser] 解析节点链接失败: $e');
          debugPrint('[Base64Parser] 堆栈: $stackTrace');
          Logger.warning('解析节点链接失败: $line', e);
        }
      }

      debugPrint('[Base64Parser] 总共解析出 ${nodes.length} 个有效节点（已过滤错误节点）');
      Logger.info('成功解析 ${nodes.length} 个节点');
      return nodes;
    } catch (e, stackTrace) {
      debugPrint('[Base64Parser] 解析 Base64 订阅失败: $e');
      debugPrint('[Base64Parser] 堆栈: $stackTrace');
      Logger.error('解析 Base64 订阅失败', e);
      return [];
    }
  }

  /// 解析单个节点链接
  static Node? _parseNodeLink(String link) {
    if (link.isEmpty) return null;

    debugPrint('[Base64Parser] _parseNodeLink 开始解析: ${link.substring(0, link.length > 80 ? 80 : link.length)}...');

    // 移除协议前缀
    String? protocol;
    String content;

    if (link.startsWith('vmess://')) {
      protocol = 'vmess';
      content = link.substring(8);
    } else if (link.startsWith('vless://')) {
      protocol = 'vless';
      content = link.substring(8);
    } else if (link.startsWith('trojan://')) {
      protocol = 'trojan';
      content = link.substring(9);
    } else if (link.startsWith('ss://')) {
      protocol = 'ss';
      // Shadowsocks 不需要解码 content，直接使用完整链接
      return _parseShadowsocks(link);
    } else if (link.startsWith('ssr://')) {
      protocol = 'ssr';
      content = link.substring(6);
    } else {
      // 尝试直接解析为 Base64
      try {
        final decoded = utf8.decode(base64Decode(link));
        return _parseNodeLink(decoded);
      } catch (e) {
        debugPrint('[Base64Parser] 无法解析为 Base64: $e');
        return null;
      }
    }

    // 解码 Base64 内容（Shadowsocks 已在上面的分支处理）
    try {
      final decoded = utf8.decode(base64Decode(content));
      
      switch (protocol) {
        case 'vmess':
          return _parseVMess(decoded);
        case 'vless':
          return _parseVLESS(decoded, link);
        case 'trojan':
          return _parseTrojan(link);
        case 'ssr':
          return _parseShadowsocksR(link);
        default:
          debugPrint('[Base64Parser] 未知协议: $protocol');
          return null;
      }
    } catch (e) {
      debugPrint('[Base64Parser] 解码节点内容失败: $protocol, 错误: $e');
      Logger.warning('解码节点内容失败: $protocol', e);
      return null;
    }
  }

  /// 解析 VMess 节点
  static Node? _parseVMess(String jsonStr) {
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final config = <String, dynamic>{
        'type': 'vmess',
        'server': json['add'],
        'port': json['port'],
        'uuid': json['id'],
        'cipher': json['scy'] ?? json['cipher'] ?? 'auto',
        'alterId': json['aid'] ?? 0,
        'network': json['net'] ?? 'tcp',
      };

      // WebSocket 配置
      if (json['net'] == 'ws' || json['net'] == 'websocket') {
        config['ws-path'] = json['path'] ?? '/';
        if (json['host'] != null) {
          config['ws-headers'] = {'Host': json['host']};
        }
      }

      // HTTP/2 配置
      if (json['net'] == 'h2' || json['net'] == 'http') {
        config['network'] = 'h2';
        config['h2-opts'] = {
          'host': json['host'] != null ? [json['host']] : [],
          'path': json['path'] ?? '/',
        };
      }

      // gRPC 配置
      if (json['net'] == 'grpc') {
        config['network'] = 'grpc';
        config['grpc-opts'] = {
          'grpc-service-name': json['path'] ?? '',
        };
      }

      // TLS 配置
      if (json['tls'] == 'tls' || json['tls'] == true) {
        config['tls'] = true;
        config['sni'] = json['sni'] ?? json['host'];
        if (json['allowInsecure'] == true || json['allow_insecure'] == true) {
          config['skip-cert-verify'] = true;
        }
      }

      // ALPN
      if (json['alpn'] != null) {
        config['alpn'] = json['alpn'] is List 
            ? json['alpn'] 
            : [json['alpn']];
      }

      return Node(
        id: _generateNodeId('vmess', json['add'] as String?, json['port']),
        name: json['ps'] as String? ?? 'VMess 节点',
        region: null,
        type: 'vmess',
        status: 'online',
        isActive: true,
        config: jsonEncode(config),
        latency: null,
        downloadSpeed: null,
      );
    } catch (e) {
      Logger.error('解析 VMess 节点失败', e);
      return null;
    }
  }

  /// 解析 VLESS 节点
  static Node? _parseVLESS(String decoded, String originalLink) {
    try {
      // VLESS 格式: vless://uuid@server:port?params#name
      final uri = Uri.parse(originalLink);
      final userInfo = uri.userInfo;
      final server = uri.host;
      final port = uri.port;

      final config = <String, dynamic>{
        'type': 'vless',
        'server': server,
        'port': port,
        'uuid': userInfo,
        'network': uri.queryParameters['type'] ?? 'tcp',
      };

      // Flow
      if (uri.queryParameters.containsKey('flow')) {
        config['flow'] = uri.queryParameters['flow'];
      }

      // WebSocket 配置
      if (uri.queryParameters['type'] == 'ws') {
        config['ws-path'] = uri.queryParameters['path'] ?? '/';
        if (uri.queryParameters.containsKey('host')) {
          config['ws-headers'] = {'Host': uri.queryParameters['host']!};
        }
      }

      // HTTP/2 配置
      if (uri.queryParameters['type'] == 'h2') {
        config['network'] = 'h2';
        config['h2-opts'] = {
          'host': uri.queryParameters['host'] != null 
              ? [uri.queryParameters['host']!] 
              : [],
          'path': uri.queryParameters['path'] ?? '/',
        };
      }

      // gRPC 配置
      if (uri.queryParameters['type'] == 'grpc') {
        config['network'] = 'grpc';
        config['grpc-opts'] = {
          'grpc-service-name': uri.queryParameters['serviceName'] ?? '',
        };
      }

      // TLS 配置（VLESS 必须使用 TLS）
      config['tls'] = true;
      if (uri.queryParameters.containsKey('sni')) {
        config['sni'] = uri.queryParameters['sni'];
      } else if (uri.queryParameters.containsKey('host')) {
        config['sni'] = uri.queryParameters['host'];
      }

      // Reality 配置
      if (uri.queryParameters.containsKey('fp')) {
        config['reality-opts'] = {
          'public-key': uri.queryParameters['pbk'],
          'short-id': uri.queryParameters['sid'],
        };
      }

      return Node(
        id: _generateNodeId('vless', server, port),
        name: uri.fragment.isNotEmpty ? uri.fragment : 'VLESS 节点',
        region: null,
        type: 'vless',
        status: 'online',
        isActive: true,
        config: jsonEncode(config),
        latency: null,
        downloadSpeed: null,
      );
    } catch (e) {
      Logger.error('解析 VLESS 节点失败', e);
      return null;
    }
  }

  /// 解析 Trojan 节点
  static Node? _parseTrojan(String link) {
    try {
      final uri = Uri.parse(link);
      final password = uri.userInfo;
      final server = uri.host;
      final port = uri.port;

      final config = <String, dynamic>{
        'type': 'trojan',
        'server': server,
        'port': port,
        'password': password,
        'tls': true, // Trojan 必须使用 TLS
      };

      // SNI
      if (uri.queryParameters.containsKey('sni')) {
        config['sni'] = uri.queryParameters['sni'];
      } else {
        config['sni'] = server;
      }

      // WebSocket 配置
      if (uri.queryParameters['type'] == 'ws') {
        config['network'] = 'ws';
        config['ws-path'] = uri.queryParameters['path'] ?? '/';
        if (uri.queryParameters.containsKey('host')) {
          config['ws-headers'] = {'Host': uri.queryParameters['host']!};
        }
      }

      // 跳过证书验证
      if (uri.queryParameters['allowInsecure'] == '1' || 
          uri.queryParameters['allow_insecure'] == '1') {
        config['skip-cert-verify'] = true;
      }

      // ALPN
      if (uri.queryParameters.containsKey('alpn')) {
        config['alpn'] = uri.queryParameters['alpn']!.split(',');
      }

      return Node(
        id: _generateNodeId('trojan', server, port),
        name: uri.fragment.isNotEmpty ? uri.fragment : 'Trojan 节点',
        region: null,
        type: 'trojan',
        status: 'online',
        isActive: true,
        config: jsonEncode(config),
        latency: null,
        downloadSpeed: null,
      );
    } catch (e) {
      Logger.error('解析 Trojan 节点失败', e);
      return null;
    }
  }

  /// 解析 Shadowsocks 节点
  static Node? _parseShadowsocks(String link) {
    try {
      debugPrint('[Base64Parser] 解析 Shadowsocks 链接: ${link.substring(0, link.length > 100 ? 100 : link.length)}');
      
      // 处理 URL 编码的 fragment
      final decodedLink = Uri.decodeComponent(link);
      debugPrint('[Base64Parser] URL 解码后: ${decodedLink.substring(0, decodedLink.length > 100 ? 100 : decodedLink.length)}');
      
      final uri = Uri.parse(decodedLink);
      final userInfo = uri.userInfo;
      final server = uri.host;
      final port = uri.hasPort ? uri.port : 443;
      
      debugPrint('[Base64Parser] userInfo: $userInfo, server: $server, port: $port');

      if (userInfo.isEmpty || server.isEmpty) {
        debugPrint('[Base64Parser] userInfo 或 server 为空');
        return null;
      }

      // 解码 userInfo (格式: method:password 的 Base64 编码)
      String method;
      String password;
      
      try {
        final decoded = base64Decode(userInfo);
        final decodedStr = utf8.decode(decoded);
        debugPrint('[Base64Parser] userInfo 解码后: $decodedStr');
        
        final parts = decodedStr.split(':');
        if (parts.length < 2) {
          debugPrint('[Base64Parser] userInfo 格式错误，parts 数量: ${parts.length}');
          return null;
        }

        method = parts[0];
        password = parts.sublist(1).join(':');
        debugPrint('[Base64Parser] method: $method, password: ${password.length > 0 ? "***" : "空"}');
      } catch (e) {
        debugPrint('[Base64Parser] 解码 userInfo 失败: $e');
        return null;
      }

      // 处理 fragment（节点名称）
      String nodeName = 'Shadowsocks 节点';
      if (uri.fragment.isNotEmpty) {
        nodeName = Uri.decodeComponent(uri.fragment);
        debugPrint('[Base64Parser] 节点名称: $nodeName');
      }

      final node = Node(
        id: _generateNodeId('ss', server, port),
        name: nodeName,
        region: null,
        type: 'ss',
        status: 'online',
        isActive: true,
        config: jsonEncode({
          'type': 'ss',
          'server': server,
          'port': port,
          'cipher': method,
          'password': password,
        }),
        latency: null,
        downloadSpeed: null,
      );
      
      debugPrint('[Base64Parser] Shadowsocks 节点解析成功: $nodeName');
      return node;
    } catch (e, stackTrace) {
      debugPrint('[Base64Parser] 解析 Shadowsocks 节点失败: $e');
      debugPrint('[Base64Parser] 堆栈: $stackTrace');
      Logger.error('解析 Shadowsocks 节点失败', e);
      return null;
    }
  }

  /// 解析 ShadowsocksR 节点
  static Node? _parseShadowsocksR(String link) {
    try {
      // SSR 格式较复杂，这里简化处理
      final decoded = utf8.decode(base64Decode(link.substring(6)));
      // TODO: 完整实现 SSR 解析
      return null;
    } catch (e) {
      Logger.error('解析 ShadowsocksR 节点失败', e);
      return null;
    }
  }

  /// 生成节点 ID
  static String _generateNodeId(String type, String? server, dynamic port) {
    final key = '${type}_${server}_${port}';
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

