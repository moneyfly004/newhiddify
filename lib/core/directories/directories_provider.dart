import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/model/directories.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directories_provider.g.dart';

@Riverpod(keepAlive: true)
class AppDirectories extends _$AppDirectories with InfraLogger {
  final _methodChannel = const MethodChannel("com.hiddify.app/platform");

  @override
  Future<Directories> build() async {
    final Directories dirs;
    // Android 和 iOS 都通过 method channel 获取路径，确保与原生代码一致
    if (Platform.isIOS || Platform.isAndroid) {
      final paths = await _methodChannel.invokeMethod<Map>("get_paths");
      loggy.debug("paths: $paths");
      dirs = (
        baseDir: Directory(paths?["base"]! as String),
        workingDir: Directory(paths?["working"]! as String),
        tempDir: Directory(paths?["temp"]! as String),
      );
    } else {
      final baseDir = await getApplicationSupportDirectory();
      final workingDir = baseDir;
      final tempDir = await getTemporaryDirectory();
      dirs = (
        baseDir: baseDir,
        workingDir: workingDir,
        tempDir: tempDir,
      );
    }

    if (!dirs.baseDir.existsSync()) {
      await dirs.baseDir.create(recursive: true);
    }
    if (!dirs.workingDir.existsSync()) {
      await dirs.workingDir.create(recursive: true);
    }

    return dirs;
  }

  static Future<Directory> getDatabaseDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      return getLibraryDirectory();
    } else if (Platform.isWindows || Platform.isLinux) {
      return getApplicationSupportDirectory();
    }
    return getApplicationDocumentsDirectory();
  }
}
