import 'package:flutter/material.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 设置菜单选择组件
class SettingsMenuTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final List<T> options;
  final String Function(T) getLabel;
  final ValueChanged<T> onChanged;

  const SettingsMenuTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.getLabel,
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
            : Text(
                getLabel(value),
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan,
                  fontSize: 12,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getLabel(value),
              style: TextStyle(
                color: CyberpunkTheme.neonCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
        onTap: () => _showMenu(context),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...options.map((option) => ListTile(
                  title: Text(
                    getLabel(option),
                    style: TextStyle(
                      color: option == value
                          ? CyberpunkTheme.neonCyan
                          : Colors.white,
                      fontWeight: option == value
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: option == value
                      ? Icon(
                          Icons.check,
                          color: CyberpunkTheme.neonCyan,
                        )
                      : null,
                  onTap: () {
                    onChanged(option);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

