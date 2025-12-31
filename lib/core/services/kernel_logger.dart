import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// 内核日志收集器
class KernelLogger {
  static const int _maxLogLines = 1000;
  static const int _maxLogFiles = 5;
  
  final List<String> _logs = [];
  final StreamController<String> _logController = StreamController<String>.broadcast();
  File? _logFile;
  StreamSubscription<String>? _logSubscription;

  KernelLogger() {
    _initLogFile();
  }

  /// 日志流
  Stream<String> get logStream => _logController.stream;

  /// 获取所有日志
  List<String> get logs => List.unmodifiable(_logs);

  /// 初始化日志文件
  Future<void> _initLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      _logFile = File('${logDir.path}/kernel_${DateTime.now().millisecondsSinceEpoch}.log');
    } catch (e) {
      Logger.error('初始化日志文件失败', e);
    }
  }

  /// 添加日志
  void addLog(String log) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $log';
    
    _logs.add(logEntry);
    if (_logs.length > _maxLogLines) {
      _logs.removeAt(0);
    }

    _logController.add(logEntry);
    
    // 写入文件
    _logFile?.writeAsStringSync('$logEntry\n', mode: FileMode.append);
    
    Logger.debug('内核日志: $log');
  }

  /// 清除日志
  void clearLogs() {
    _logs.clear();
    _logController.add('日志已清除');
  }

  /// 保存日志到文件
  Future<String?> saveLogs() async {
    if (_logFile == null) return null;
    try {
      await _logFile!.writeAsString(_logs.join('\n'));
      return _logFile!.path;
    } catch (e) {
      Logger.error('保存日志失败', e);
      return null;
    }
  }

  /// 清理旧日志文件
  Future<void> cleanupOldLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) return;

      final files = logDir.listSync()
          .whereType<File>()
          .where((f) => f.path.contains('kernel_'))
          .toList();
      
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      if (files.length > _maxLogFiles) {
        for (var file in files.sublist(_maxLogFiles)) {
          await file.delete();
        }
      }
    } catch (e) {
      Logger.error('清理旧日志失败', e);
    }
  }

  /// 释放资源
  void dispose() {
    _logSubscription?.cancel();
    _logController.close();
  }
}

