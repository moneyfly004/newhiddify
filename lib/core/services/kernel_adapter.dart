import 'dart:convert';
import 'package:yaml/yaml.dart' as yaml;
import '../models/kernel_type.dart';
import 'kernel_manager.dart';

/// 内核适配器接口
abstract class IKernelAdapter {
  /// 内核类型
  KernelType get kernelType;

  /// 启动内核
  Future<void> start(String config);

  /// 停止内核
  Future<void> stop();

  /// 重新加载配置
  Future<void> reload(String config);

  /// 获取状态
  Future<Map<String, dynamic>> getStatus();

  /// 验证配置
  bool validateConfig(String config);
}

/// Sing-box 适配器
class SingboxAdapter implements IKernelAdapter {
  final KernelManager _kernelManager;

  SingboxAdapter(this._kernelManager);

  @override
  KernelType get kernelType => KernelType.singbox;

  @override
  Future<void> start(String config) async {
    if (_kernelManager.currentKernel != KernelType.singbox) {
      await _kernelManager.switchKernel(KernelType.singbox);
    }
    await _kernelManager.startKernel(config);
  }

  @override
  Future<void> stop() async {
    await _kernelManager.stopKernel();
  }

  @override
  Future<void> reload(String config) async {
    await _kernelManager.reloadConfig(config);
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return await _kernelManager.getKernelStatus();
  }

  @override
  bool validateConfig(String config) {
    try {
      // 验证 JSON 格式
      final json = jsonDecode(config);
      if (json is! Map<String, dynamic>) return false;
      
      // 验证必需字段
      return json.containsKey('log') || 
             json.containsKey('inbounds') || 
             json.containsKey('outbounds');
    } catch (e) {
      return false;
    }
  }
}

/// Clash Meta 适配器
class ClashMetaAdapter implements IKernelAdapter {
  final KernelManager _kernelManager;

  ClashMetaAdapter(this._kernelManager);

  @override
  KernelType get kernelType => KernelType.mihomo;

  @override
  Future<void> start(String config) async {
    if (_kernelManager.currentKernel != KernelType.mihomo) {
      await _kernelManager.switchKernel(KernelType.mihomo);
    }
    await _kernelManager.startKernel(config);
  }

  @override
  Future<void> stop() async {
    await _kernelManager.stopKernel();
  }

  @override
  Future<void> reload(String config) async {
    await _kernelManager.reloadConfig(config);
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    return await _kernelManager.getKernelStatus();
  }

  @override
  bool validateConfig(String config) {
    try {
      // 验证 YAML 格式
      final yamlDoc = yaml.loadYaml(config);
      if (yamlDoc is! Map) return false;
      
      // 验证必需字段
      return yamlDoc.containsKey('port') || 
             yamlDoc.containsKey('proxies') ||
             yamlDoc.containsKey('proxy-groups');
    } catch (e) {
      return false;
    }
  }
}

/// 内核适配器工厂
class KernelAdapterFactory {
  static IKernelAdapter createAdapter(KernelType type, KernelManager kernelManager) {
    switch (type) {
      case KernelType.singbox:
        return SingboxAdapter(kernelManager);
      case KernelType.mihomo:
        return ClashMetaAdapter(kernelManager);
    }
  }
}

