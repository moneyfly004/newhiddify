import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/logger.dart';
import 'encryption_service.dart';

/// 配置文件管理器
class ConfigFileManager {
  static const String _configDirName = 'configs';
  static const int _maxBackupFiles = 10;

  /// 保存配置文件
  static Future<String> saveConfig({
    required String config,
    required String kernelType,
    String? version,
  }) async {
    try {
      final dir = await _getConfigDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${kernelType}_$timestamp.json';
      final file = File('${dir.path}/$fileName');

      // 加密配置
      final seed = _getEncryptionSeed();
      final encrypted = EncryptionService.encrypt(config, seed);

      await file.writeAsString(encrypted);

      // 保存版本信息
      if (version != null) {
        final versionFile = File('${dir.path}/$fileName.version');
        await versionFile.writeAsString(version);
      }

      Logger.info('配置文件已保存: $fileName');
      return file.path;
    } catch (e) {
      Logger.error('保存配置文件失败', e);
      rethrow;
    }
  }

  /// 加载配置文件
  static Future<String?> loadConfig(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final encrypted = await file.readAsString();
      final seed = _getEncryptionSeed();
      final config = EncryptionService.decrypt(encrypted, seed);

      Logger.info('配置文件已加载: $filePath');
      return config;
    } catch (e) {
      Logger.error('加载配置文件失败', e);
      return null;
    }
  }

  /// 获取最新配置文件
  static Future<String?> getLatestConfig(String kernelType) async {
    try {
      final dir = await _getConfigDirectory();
      if (!await dir.exists()) {
        return null;
      }

      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.contains(kernelType))
          .where((f) => !f.path.contains('.version'))
          .toList();

      if (files.isEmpty) {
        return null;
      }

      // 按时间排序，获取最新的
      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });

      return await loadConfig(files.first.path);
    } catch (e) {
      Logger.error('获取最新配置文件失败', e);
      return null;
    }
  }

  /// 备份配置文件
  static Future<String> backupConfig(String config, String kernelType) async {
    final version = _generateVersion(config);
    return await saveConfig(
      config: config,
      kernelType: kernelType,
      version: version,
    );
  }

  /// 恢复配置文件
  static Future<String?> restoreConfig(String filePath) async {
    return await loadConfig(filePath);
  }

  /// 清理旧配置文件
  static Future<void> cleanupOldConfigs() async {
    try {
      final dir = await _getConfigDirectory();
      if (!await dir.exists()) {
        return;
      }

      final files = dir.listSync()
          .whereType<File>()
          .where((f) => !f.path.contains('.version'))
          .toList();

      if (files.length <= _maxBackupFiles) {
        return;
      }

      // 按时间排序
      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });

      // 删除最旧的文件
      for (var file in files.sublist(_maxBackupFiles)) {
        await file.delete();
        // 删除对应的版本文件
        final versionFile = File('${file.path}.version');
        if (await versionFile.exists()) {
          await versionFile.delete();
        }
      }

      Logger.info('已清理 ${files.length - _maxBackupFiles} 个旧配置文件');
    } catch (e) {
      Logger.error('清理旧配置文件失败', e);
    }
  }

  /// 清理临时配置文件
  static Future<void> cleanupTempConfigs() async {
    try {
      final dir = await _getConfigDirectory();
      if (!await dir.exists()) {
        return;
      }

      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.contains('temp') || f.path.contains('tmp'))
          .toList();

      for (var file in files) {
        await file.delete();
      }

      Logger.info('已清理 ${files.length} 个临时配置文件');
    } catch (e) {
      Logger.error('清理临时配置文件失败', e);
    }
  }

  /// 获取配置目录
  static Future<Directory> _getConfigDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final configDir = Directory('${appDir.path}/$_configDirName');
    
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    return configDir;
  }

  /// 生成配置版本（基于内容哈希）
  static String _generateVersion(String config) {
    final bytes = utf8.encode(config);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }

  /// 获取加密种子
  static String _getEncryptionSeed() {
    // 使用应用包名作为种子
    return 'proxy_app_config_seed';
  }

  /// 获取配置文件列表
  static Future<List<ConfigFileInfo>> getConfigFileList() async {
    try {
      final dir = await _getConfigDirectory();
      if (!await dir.exists()) {
        return [];
      }

      final files = dir.listSync()
          .whereType<File>()
          .where((f) => !f.path.contains('.version'))
          .toList();

      final fileList = <ConfigFileInfo>[];

      for (var file in files) {
        final stat = file.statSync();
        final versionFile = File('${file.path}.version');
        String? version;
        
        if (await versionFile.exists()) {
          version = await versionFile.readAsString();
        }

        fileList.add(ConfigFileInfo(
          path: file.path,
          name: file.path.split('/').last,
          size: stat.size,
          modified: stat.modified,
          version: version,
        ));
      }

      // 按修改时间排序
      fileList.sort((a, b) => b.modified.compareTo(a.modified));

      return fileList;
    } catch (e) {
      Logger.error('获取配置文件列表失败', e);
      return [];
    }
  }
}

/// 配置文件信息
class ConfigFileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String? version;

  ConfigFileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    this.version,
  });
}

