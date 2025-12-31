import '../models/connection_mode.dart';

/// DNS 管理器
class DnsManager {
  /// 获取 DNS 配置（Sing-box 格式）
  static Map<String, dynamic> getSingboxDns({
    List<String>? servers,
    bool enableDoH = false,
    bool enableDoT = false,
  }) {
    final dnsServers = <Map<String, dynamic>>[];

    // 添加普通 DNS 服务器
    if (servers != null && servers.isNotEmpty) {
      for (final server in servers) {
        dnsServers.add({
          'address': server,
          'address_resolver': 'local',
        });
      }
    } else {
      // 默认 DNS 服务器
      dnsServers.addAll([
        {'address': '223.5.5.5', 'address_resolver': 'local'},  // 阿里 DNS
        {'address': '119.29.29.29', 'address_resolver': 'local'},  // 腾讯 DNS
        {'address': '8.8.8.8', 'address_resolver': 'local'},  // Google DNS
      ]);
    }

    // 添加 DoH 服务器
    if (enableDoH) {
      dnsServers.addAll([
        {
          'address': 'https://doh.pub/dns-query',
          'address_resolver': 'local',
        },
        {
          'address': 'https://dns.alidns.com/dns-query',
          'address_resolver': 'local',
        },
      ]);
    }

    // 添加 DoT 服务器
    if (enableDoT) {
      dnsServers.addAll([
        {
          'address': 'tls://dns.alidns.com',
          'address_resolver': 'local',
        },
      ]);
    }

    return {
      'servers': dnsServers,
      'rules': _getDnsRules(),
    };
  }

  /// 获取 DNS 配置（Clash 格式）
  static Map<String, dynamic> getClashDns({
    List<String>? servers,
    bool enableDoH = false,
    bool enableDoT = false,
  }) {
    final dns = <String, dynamic>{
      'enable': true,
      'listen': '0.0.0.0:53',
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'nameserver': servers ?? [
        '223.5.5.5',
        '119.29.29.29',
        '8.8.8.8',
      ],
    };

    if (enableDoH) {
      dns['doh'] = [
        'https://doh.pub/dns-query',
        'https://dns.alidns.com/dns-query',
      ];
    }

    if (enableDoT) {
      dns['dot'] = [
        'tls://dns.alidns.com',
      ];
    }

    return dns;
  }

  /// 获取 DNS 规则
  static List<Map<String, dynamic>> _getDnsRules() {
    return [
      // 中国域名使用国内 DNS
      {
        'domain_suffix': ['.cn'],
        'server': '223.5.5.5',
      },
      // 其他使用默认 DNS
      {
        'server': '8.8.8.8',
      },
    ];
  }

  /// 获取推荐的 DNS 服务器列表
  static List<DnsServer> getRecommendedServers() {
    return [
      DnsServer(name: '阿里 DNS', address: '223.5.5.5', type: DnsType.udp),
      DnsServer(name: '腾讯 DNS', address: '119.29.29.29', type: DnsType.udp),
      DnsServer(name: 'Google DNS', address: '8.8.8.8', type: DnsType.udp),
      DnsServer(name: 'Cloudflare DNS', address: '1.1.1.1', type: DnsType.udp),
      DnsServer(name: '阿里 DoH', address: 'https://dns.alidns.com/dns-query', type: DnsType.doh),
      DnsServer(name: '腾讯 DoH', address: 'https://doh.pub/dns-query', type: DnsType.doh),
      DnsServer(name: 'Cloudflare DoH', address: 'https://cloudflare-dns.com/dns-query', type: DnsType.doh),
    ];
  }
}

/// DNS 服务器
class DnsServer {
  final String name;
  final String address;
  final DnsType type;

  DnsServer({
    required this.name,
    required this.address,
    required this.type,
  });
}

/// DNS 类型
enum DnsType {
  udp,
  tcp,
  doh,
  dot,
}

