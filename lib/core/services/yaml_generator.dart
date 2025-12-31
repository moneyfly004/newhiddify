import 'dart:convert';

/// YAML 生成器 - 将 Map 转换为 YAML 字符串
class YamlGenerator {
  /// 将 Map 转换为 YAML 字符串
  static String mapToYaml(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    _writeYamlValue(buffer, map, 0);
    return buffer.toString();
  }

  static void _writeYamlValue(StringBuffer buffer, dynamic value, int indent) {
    final indentStr = '  ' * indent;
    
    if (value is Map) {
      value.forEach((key, val) {
        if (val is Map || val is List) {
          buffer.writeln('$indentStr$key:');
          _writeYamlValue(buffer, val, indent + 1);
        } else {
          buffer.writeln('$indentStr$key: ${_yamlValue(val)}');
        }
      });
    } else if (value is List) {
      for (var item in value) {
        if (item is Map) {
          buffer.writeln('$indentStr-');
          _writeYamlValue(buffer, item, indent + 1);
        } else {
          buffer.writeln('$indentStr- ${_yamlValue(item)}');
        }
      }
    }
  }

  static String _yamlValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) {
      // 如果包含特殊字符，需要引号
      if (value.contains(' ') || 
          value.contains(':') || 
          value.contains('#') ||
          value.contains('|') ||
          value.contains('&') ||
          value.contains('*') ||
          value.contains('!') ||
          value.contains('%') ||
          value.contains('@') ||
          value.contains('`')) {
        return '"${value.replaceAll('"', '\\"')}"';
      }
      return value;
    }
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is List) {
      if (value.isEmpty) return '[]';
      final buffer = StringBuffer();
      for (var item in value) {
        buffer.writeln('  - ${_yamlValue(item)}');
      }
      return '\n$buffer';
    }
    return value.toString();
  }
}

