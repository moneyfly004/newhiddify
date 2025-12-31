/// 连接模式
enum ConnectionMode {
  /// 规则模式：根据规则决定是否走代理
  rules,
  
  /// 全局模式：所有流量都走代理
  global,
}

/// 连接模式扩展
extension ConnectionModeExtension on ConnectionMode {
  /// 显示名称
  String get displayName {
    switch (this) {
      case ConnectionMode.rules:
        return '规则';
      case ConnectionMode.global:
        return '全局';
    }
  }

  /// 描述
  String get description {
    switch (this) {
      case ConnectionMode.rules:
        return '根据规则智能分流，国内直连，国外代理';
      case ConnectionMode.global:
        return '所有流量都通过代理';
    }
  }
}

