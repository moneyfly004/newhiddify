/// 内核类型枚举
enum KernelType {
  singbox,
  mihomo, // Clash Meta
}

/// 内核类型扩展
extension KernelTypeExtension on KernelType {
  /// 获取显示名称
  String get displayName {
    switch (this) {
      case KernelType.singbox:
        return 'Sing-box';
      case KernelType.mihomo:
        return 'Clash Meta';
    }
  }

  /// 获取描述
  String get description {
    switch (this) {
      case KernelType.singbox:
        return '高性能、现代化的代理内核';
      case KernelType.mihomo:
        return '功能丰富的 Clash Meta 内核';
    }
  }
}
