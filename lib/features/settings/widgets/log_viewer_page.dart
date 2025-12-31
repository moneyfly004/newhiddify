import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../../core/services/kernel_logger.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 日志查看器页面
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  bool _autoScroll = true;
  StreamSubscription<String>? _logSubscription;
  KernelLogger? _kernelLogger;

  @override
  void initState() {
    super.initState();
    _initLogger();
  }

  void _initLogger() {
    try {
      _kernelLogger = GetIt.instance<KernelLogger>();
      _logSubscription = _kernelLogger!.logStream.listen((log) {
        if (mounted) {
          setState(() {
            _logs.add(log);
            if (_logs.length > 1000) {
              _logs.removeAt(0);
            }
          });
          if (_autoScroll && _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
      // 加载现有日志
      _loadLogs();
    } catch (e) {
      // 如果 KernelLogger 未注册，使用模拟数据
      _loadMockLogs();
    }
  }

  Future<void> _loadLogs() async {
    if (_kernelLogger != null) {
      final logs = _kernelLogger!.logs;
      if (mounted) {
        setState(() {
          _logs.clear();
          _logs.addAll(logs);
        });
      }
    }
  }

  void _loadMockLogs() {
    setState(() {
      _logs.addAll([
        '[INFO] 内核启动成功',
        '[DEBUG] 配置加载完成',
        '[INFO] 连接到服务器...',
        '[WARN] 连接超时，正在重试...',
        '[INFO] 连接成功',
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志查看器'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
            tooltip: _autoScroll ? '关闭自动滚动' : '开启自动滚动',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: '复制日志',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
            tooltip: '清空日志',
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(child: Text('暂无日志'))
          : ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final color = _getLogColor(log);
                
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getLogColor(String log) {
    if (log.contains('[ERROR]')) {
      return Colors.red;
    } else if (log.contains('[WARN]')) {
      return Colors.orange;
    } else if (log.contains('[INFO]')) {
      return CyberpunkTheme.neonCyan;
    } else if (log.contains('[DEBUG]')) {
      return Colors.blue;
    }
    return Colors.white70;
  }

  void _copyLogs() {
    final text = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }

  void _clearLogs() {
    if (_kernelLogger != null) {
      _kernelLogger!.clearLogs();
    }
    setState(() => _logs.clear());
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

