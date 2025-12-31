import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';
import '../utils/cache_manager.dart';
import '../models/connection_mode.dart';

/// 规则管理器
class RuleManager {
  static const String _defaultRulesKey = 'default_rules';
  static const String _customRulesKey = 'custom_rules';

  /// 获取规则（Sing-box 格式）
  static List<Map<String, dynamic>> getSingboxRules(ConnectionMode mode) {
    if (mode == ConnectionMode.global) {
      return [];
    }

    // 默认规则
    final defaultRules = _getDefaultSingboxRules();
    
    // 自定义规则
    final customRules = _getCustomSingboxRules();
    
    return [...defaultRules, ...customRules];
  }

  /// 获取规则（Clash 格式）
  static List<String> getClashRules(ConnectionMode mode) {
    if (mode == ConnectionMode.global) {
      return [];
    }

    // 默认规则
    final defaultRules = _getDefaultClashRules();
    
    // 自定义规则
    final customRules = _getCustomClashRules();
    
    return [...defaultRules, ...customRules];
  }

  /// 默认 Sing-box 规则
  static List<Map<String, dynamic>> _getDefaultSingboxRules() {
    return [
      // 直连本地
      {
        'domain_suffix': ['.local'],
        'outbound': 'direct',
      },
      // 直连局域网
      {
        'ip_cidr': ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8'],
        'outbound': 'direct',
      },
      // 直连中国域名
      {
        'domain_suffix': ['.cn'],
        'outbound': 'direct',
      },
      // 直连中国 IP
      {
        'geoip': ['cn'],
        'outbound': 'direct',
      },
      // 其他走代理
      {
        'network': 'tcp,udp',
        'outbound': 'proxy',
      },
    ];
  }

  /// 默认 Clash 规则
  static List<String> _getDefaultClashRules() {
    return [
      'DOMAIN-SUFFIX,local,DIRECT',
      'IP-CIDR,10.0.0.0/8,DIRECT',
      'IP-CIDR,172.16.0.0/12,DIRECT',
      'IP-CIDR,192.168.0.0/16,DIRECT',
      'IP-CIDR,127.0.0.0/8,DIRECT',
      'DOMAIN-SUFFIX,cn,DIRECT',
      'GEOIP,CN,DIRECT',
      'MATCH,PROXY',
    ];
  }

  /// 获取自定义 Sing-box 规则
  static List<Map<String, dynamic>> _getCustomSingboxRules() {
    // TODO: 从存储中读取自定义规则
    return [];
  }

  /// 获取自定义 Clash 规则
  static List<String> _getCustomClashRules() {
    // TODO: 从存储中读取自定义规则
    return [];
  }

  /// 保存自定义规则
  static Future<void> saveCustomRules(List<Map<String, dynamic>> rules) async {
    await CacheManager.setCache(_customRulesKey, rules);
    Logger.info('已保存自定义规则: ${rules.length} 条');
  }

  /// 加载规则文件
  static Future<List<String>> loadRuleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('规则文件不存在: $filePath');
      }

      final content = await file.readAsString();
      return content.split('\n')
          .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('#'))
          .toList();
    } catch (e) {
      Logger.error('加载规则文件失败', e);
      rethrow;
    }
  }

  /// 下载远程规则文件
  static Future<List<String>> downloadRuleFile(String url) async {
    try {
      // TODO: 使用 Dio 下载规则文件
      // final response = await dio.get(url);
      // return response.data.toString().split('\n')
      //     .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('#'))
      //     .toList();
      throw UnimplementedError('需要实现远程规则下载');
    } catch (e) {
      Logger.error('下载规则文件失败', e);
      rethrow;
    }
  }

  /// 验证规则
  static bool validateRule(String rule) {
    // 简单的规则验证
    if (rule.trim().isEmpty) return false;
    
    // Clash 规则格式验证
    if (rule.contains(',')) {
      final parts = rule.split(',');
      if (parts.length < 2) return false;
    }
    
    return true;
  }

  /// 测试规则
  static Future<bool> testRule(String rule, String testDomain) async {
    // TODO: 实现规则测试逻辑
    return true;
  }
}

