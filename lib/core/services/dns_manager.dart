import '../models/connection_mode.dart';

/// DNS 管理器
class DnsManager {
  /// 获取 DNS 配置（Sing-box 格式，参考 NekoBoxForAndroid）
  static Map<String, dynamic> getSingboxDns({
    List<String>? remoteDns,
    List<String>? directDns,
    bool enableFakeDns = false,
    bool enableDnsRouting = true,
  }) {
    final dnsServers = <Map<String, dynamic>>[];

    // 1. DNS block（用于阻止 DNS 查询）
    dnsServers.add({
      'tag': 'dns-block',
      'address': 'rcode://success',
    });

    // 2. DNS local（本地 DNS 解析器，必须）
    dnsServers.add({
      'tag': 'dns-local',
      'address': 'local',
      'detour': 'direct',
    });

    // 3. DNS direct（直连 DNS，用于解析代理服务器地址）
    final directDnsList = directDns ?? ['https://223.5.5.5/dns-query'];
    dnsServers.add({
      'tag': 'dns-direct',
      'address': directDnsList.first,
      'detour': 'direct',
      'address_resolver': 'dns-local',
      'strategy': 'prefer_ipv4',
    });

    // 4. DNS remote（远程 DNS，通过代理解析）
    final remoteDnsList = remoteDns ?? ['https://dns.google/dns-query'];
    dnsServers.add({
      'tag': 'dns-remote',
      'address': remoteDnsList.first,
      'address_resolver': 'dns-direct',
      'strategy': 'prefer_ipv4',
    });

    // 5. DNS fake（FakeDNS，用于流量嗅探）
    if (enableFakeDns) {
      dnsServers.add({
        'tag': 'dns-fake',
        'address': 'fakedns',
      });
    }

    return {
      'servers': dnsServers,
      'final': 'dns-remote',  // 默认使用远程 DNS
      'rules': enableDnsRouting ? _getDnsRules() : [],
      'independent_cache': true,
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

  /// 获取 DNS 规则（参考 NekoBoxForAndroid）
  static List<Map<String, dynamic>> _getDnsRules() {
    return [
      // 中国域名使用直连 DNS
      {
        'domain_suffix': ['.cn'],
        'server': 'dns-direct',
      },
      // 其他域名使用远程 DNS（通过代理）
      {
        'server': 'dns-remote',
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

