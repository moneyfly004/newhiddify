import 'dart:convert';
import '../utils/logger.dart';

/// 协议转换器 - 处理不同内核间的协议转换
class ProtocolConverter {
  /// 将节点从 Clash 格式转换为 Sing-box 格式
  static Map<String, dynamic> clashToSingbox(Map<String, dynamic> clashNode) {
    final type = clashNode['type'] as String? ?? '';
    final name = clashNode['name'] as String? ?? '';

    switch (type) {
      case 'vmess':
        return _vmessClashToSingbox(clashNode, name);
      case 'vless':
        return _vlessClashToSingbox(clashNode, name);
      case 'trojan':
        return _trojanClashToSingbox(clashNode, name);
      case 'ss':
      case 'shadowsocks':
        return _ssClashToSingbox(clashNode, name);
      case 'ssr':
        return _ssrClashToSingbox(clashNode, name);
      case 'hysteria':
      case 'hysteria2':
        return _hysteriaClashToSingbox(clashNode, name);
      case 'tuic':
        return _tuicClashToSingbox(clashNode, name);
      default:
        throw Exception('不支持的协议类型: $type');
    }
  }

  /// 将节点从 Sing-box 格式转换为 Clash 格式
  static Map<String, dynamic> singboxToClash(Map<String, dynamic> singboxNode) {
    final type = singboxNode['type'] as String? ?? '';
    final tag = singboxNode['tag'] as String? ?? '';

    switch (type) {
      case 'vmess':
        return _vmessSingboxToClash(singboxNode, tag);
      case 'vless':
        return _vlessSingboxToClash(singboxNode, tag);
      case 'trojan':
        return _trojanSingboxToClash(singboxNode, tag);
      case 'shadowsocks':
        return _ssSingboxToClash(singboxNode, tag);
      case 'hysteria':
      case 'hysteria2':
        return _hysteriaSingboxToClash(singboxNode, tag);
      case 'tuic':
        return _tuicSingboxToClash(singboxNode, tag);
      default:
        throw Exception('不支持的协议类型: $type');
    }
  }

  // ==================== VMess 转换 ====================

  static Map<String, dynamic> _vmessClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    final outbound = {
      'type': 'vmess',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'uuid': clash['uuid'],
      'security': clash['cipher'] ?? 'auto',
      'alter_id': clash['alterId'] ?? 0,
    };

    // 传输协议
    _addTransportClashToSingbox(clash, outbound);

    // TLS 配置
    _addTlsClashToSingbox(clash, outbound);

    return outbound;
  }

  static Map<String, dynamic> _vmessSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    final proxy = {
      'name': tag,
      'type': 'vmess',
      'server': singbox['server'],
      'port': singbox['server_port'],
      'uuid': singbox['uuid'],
      'cipher': singbox['security'] ?? 'auto',
      'alterId': singbox['alter_id'] ?? 0,
    };

    // 传输协议
    _addTransportSingboxToClash(singbox, proxy);

    // TLS 配置
    _addTlsSingboxToClash(singbox, proxy);

    return proxy;
  }

  // ==================== VLESS 转换 ====================

  static Map<String, dynamic> _vlessClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    final outbound = {
      'type': 'vless',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'uuid': clash['uuid'],
      'flow': clash['flow'] ?? '',
    };

    // 传输协议
    _addTransportClashToSingbox(clash, outbound);

    // TLS 配置（VLESS 必须使用 TLS）
    _addTlsClashToSingbox(clash, outbound, required: true);

    return outbound;
  }

  static Map<String, dynamic> _vlessSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    final proxy = {
      'name': tag,
      'type': 'vless',
      'server': singbox['server'],
      'port': singbox['server_port'],
      'uuid': singbox['uuid'],
    };

    if (singbox.containsKey('flow')) {
      proxy['flow'] = singbox['flow'];
    }

    // 传输协议
    _addTransportSingboxToClash(singbox, proxy);

    // TLS 配置
    _addTlsSingboxToClash(singbox, proxy);

    return proxy;
  }

  // ==================== Trojan 转换 ====================

  static Map<String, dynamic> _trojanClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    final outbound = {
      'type': 'trojan',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'password': clash['password'],
    };

    // 传输协议
    _addTransportClashToSingbox(clash, outbound);

    // TLS 配置（Trojan 必须使用 TLS）
    _addTlsClashToSingbox(clash, outbound, required: true);

    return outbound;
  }

  static Map<String, dynamic> _trojanSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    final proxy = {
      'name': tag,
      'type': 'trojan',
      'server': singbox['server'],
      'port': singbox['server_port'],
      'password': singbox['password'],
    };

    // 传输协议
    _addTransportSingboxToClash(singbox, proxy);

    // TLS 配置
    _addTlsSingboxToClash(singbox, proxy);

    return proxy;
  }

  // ==================== Shadowsocks 转换 ====================

  static Map<String, dynamic> _ssClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    return {
      'type': 'shadowsocks',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'method': clash['cipher'],
      'password': clash['password'],
      'plugin': clash['plugin'] ?? '',
      'plugin_opts': clash['plugin-opts'] ?? clash['plugin_opts'] ?? '',
    };
  }

  static Map<String, dynamic> _ssSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    return {
      'name': tag,
      'type': 'ss',
      'server': singbox['server'],
      'port': singbox['server_port'],
      'cipher': singbox['method'],
      'password': singbox['password'],
    };
  }

  // ==================== ShadowsocksR 转换 ====================

  static Map<String, dynamic> _ssrClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    // SSR 在 Sing-box 中需要特殊处理
    return {
      'type': 'shadowsocks',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'method': clash['cipher'],
      'password': clash['password'],
    };
  }

  // ==================== Hysteria 转换 ====================

  static Map<String, dynamic> _hysteriaClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    return {
      'type': clash['type'] == 'hysteria2' ? 'hysteria2' : 'hysteria',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'password': clash['password'] ?? clash['auth_str'],
      'obfs': clash['obfs'] ?? '',
    };
  }

  static Map<String, dynamic> _hysteriaSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    return {
      'name': tag,
      'type': singbox['type'],
      'server': singbox['server'],
      'port': singbox['server_port'],
      'password': singbox['password'],
    };
  }

  // ==================== TUIC 转换 ====================

  static Map<String, dynamic> _tuicClashToSingbox(
    Map<String, dynamic> clash,
    String name,
  ) {
    return {
      'type': 'tuic',
      'tag': name,
      'server': clash['server'],
      'server_port': clash['port'],
      'uuid': clash['uuid'],
      'password': clash['password'],
    };
  }

  static Map<String, dynamic> _tuicSingboxToClash(
    Map<String, dynamic> singbox,
    String tag,
  ) {
    return {
      'name': tag,
      'type': 'tuic',
      'server': singbox['server'],
      'port': singbox['server_port'],
      'uuid': singbox['uuid'],
      'password': singbox['password'],
    };
  }

  // ==================== 传输协议转换 ====================

  /// 添加传输协议（Clash -> Sing-box）
  static void _addTransportClashToSingbox(
    Map<String, dynamic> clash,
    Map<String, dynamic> outbound,
  ) {
    final network = clash['network'] as String?;
    if (network == null || network == 'tcp') {
      return; // TCP 是默认，不需要配置
    }

    switch (network) {
      case 'ws':
      case 'websocket':
        outbound['transport'] = {
          'type': 'ws',
          'path': clash['ws-path'] ?? clash['ws_path'] ?? '/',
          'headers': _convertHeaders(clash['ws-headers'] ?? clash['ws_headers'] ?? {}),
        };
        break;

      case 'h2':
      case 'http':
        final h2Opts = clash['h2-opts'] ?? clash['h2_opts'] ?? {};
        outbound['transport'] = {
          'type': 'http',
          'host': (h2Opts['host'] as List?)?.cast<String>() ?? [],
          'path': h2Opts['path'] ?? '/',
        };
        break;

      case 'grpc':
        final grpcOpts = clash['grpc-opts'] ?? clash['grpc_opts'] ?? {};
        outbound['transport'] = {
          'type': 'grpc',
          'service_name': grpcOpts['grpc-service-name'] ?? grpcOpts['grpc_service_name'] ?? '',
        };
        break;

      case 'quic':
        outbound['transport'] = {
          'type': 'quic',
        };
        break;
    }
  }

  /// 添加传输协议（Sing-box -> Clash）
  static void _addTransportSingboxToClash(
    Map<String, dynamic> singbox,
    Map<String, dynamic> proxy,
  ) {
    final transport = singbox['transport'] as Map<String, dynamic>?;
    if (transport == null) {
      return; // TCP 是默认
    }

    final transportType = transport['type'] as String?;
    switch (transportType) {
      case 'ws':
        proxy['network'] = 'ws';
        proxy['ws-path'] = transport['path'] ?? '/';
        final headers = transport['headers'] as Map<String, dynamic>?;
        if (headers != null && headers.isNotEmpty) {
          proxy['ws-headers'] = headers;
        }
        break;

      case 'http':
        proxy['network'] = 'h2';
        proxy['h2-opts'] = {
          'host': transport['host'] ?? [],
          'path': transport['path'] ?? '/',
        };
        break;

      case 'grpc':
        proxy['network'] = 'grpc';
        proxy['grpc-opts'] = {
          'grpc-service-name': transport['service_name'] ?? '',
        };
        break;

      case 'quic':
        proxy['network'] = 'quic';
        break;
    }
  }

  // ==================== TLS 配置转换 ====================

  /// 添加 TLS 配置（Clash -> Sing-box）
  static void _addTlsClashToSingbox(
    Map<String, dynamic> clash,
    Map<String, dynamic> outbound, {
    bool required = false,
  }) {
    final tls = clash['tls'] ?? false;
    if (!tls && !required) {
      return;
    }

    final tlsConfig = <String, dynamic>{
      'enabled': true,
    };

    // SNI
    final sni = clash['sni'] ?? clash['servername'] ?? clash['server_name'];
    if (sni != null) {
      tlsConfig['server_name'] = sni;
    }

    // 跳过证书验证
    if (clash['skip-cert-verify'] == true || clash['skip_cert_verify'] == true) {
      tlsConfig['insecure'] = true;
    }

    // ALPN
    final alpn = clash['alpn'] as List?;
    if (alpn != null && alpn.isNotEmpty) {
      tlsConfig['alpn'] = alpn.cast<String>();
    }

    // Reality 配置
    if (clash.containsKey('reality-opts') || clash.containsKey('reality_opts')) {
      final realityOpts = clash['reality-opts'] ?? clash['reality_opts'] ?? {};
      tlsConfig['reality'] = {
        'enabled': true,
        'public_key': realityOpts['public-key'] ?? realityOpts['public_key'],
        'short_id': realityOpts['short-id'] ?? realityOpts['short_id'],
      };
    }

    outbound['tls'] = tlsConfig;
  }

  /// 添加 TLS 配置（Sing-box -> Clash）
  static void _addTlsSingboxToClash(
    Map<String, dynamic> singbox,
    Map<String, dynamic> proxy,
  ) {
    final tls = singbox['tls'] as Map<String, dynamic>?;
    if (tls == null || tls['enabled'] != true) {
      return;
    }

    proxy['tls'] = true;

    // SNI
    if (tls.containsKey('server_name')) {
      proxy['sni'] = tls['server_name'];
    }

    // 跳过证书验证
    if (tls['insecure'] == true) {
      proxy['skip-cert-verify'] = true;
    }

    // ALPN
    if (tls.containsKey('alpn')) {
      proxy['alpn'] = tls['alpn'];
    }

    // Reality 配置
    if (tls.containsKey('reality')) {
      final reality = tls['reality'] as Map<String, dynamic>?;
      if (reality != null && reality['enabled'] == true) {
        proxy['reality-opts'] = {
          'public-key': reality['public_key'],
          'short-id': reality['short_id'],
        };
      }
    }
  }

  // ==================== 辅助方法 ====================

  /// 转换 Headers
  static Map<String, dynamic> _convertHeaders(dynamic headers) {
    if (headers is Map) {
      return Map<String, dynamic>.from(headers);
    }
    return {};
  }
}

