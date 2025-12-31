import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 设置文本输入组件
class SettingsTextFieldTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const SettingsTextFieldTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.keyboardType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: CyberpunkTheme.neonCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit, color: Colors.white70, size: 18),
          ],
        ),
        onTap: () => _showEditDialog(context),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: subtitle ?? '请输入',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: CyberpunkTheme.neonCyan),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: CyberpunkTheme.neonCyan),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onChanged(controller.text);
              Navigator.pop(context);
            },
            child: Text(
              '确定',
              style: TextStyle(color: CyberpunkTheme.neonCyan),
            ),
          ),
        ],
      ),
    );
  }
}

