import 'package:flutter/material.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 连接按钮组件
class ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onToggle;

  const ConnectionButton({
    super.key,
    required this.isConnected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? CyberpunkTheme.neonGreen
        : CyberpunkTheme.neonCyan;

    return Center(
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            boxShadow: CyberpunkTheme.neonGlow(color),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.power_settings_new,
                size: 56,
                color: CyberpunkTheme.darkBg,
              ),
              const SizedBox(height: 8),
              Text(
                isConnected ? '已连接' : '连接',
                style: TextStyle(
                  color: CyberpunkTheme.darkBg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

