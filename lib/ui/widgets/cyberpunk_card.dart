import 'package:flutter/material.dart';
import '../theme/cyberpunk_theme.dart';

/// 赛博朋克风格卡片
class CyberpunkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showGradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  const CyberpunkCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.showGradient = true,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin ?? const EdgeInsets.all(16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: showGradient
          ? CyberpunkTheme.neonGradient()
          : BoxDecoration(
              color: CyberpunkTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor ?? CyberpunkTheme.neonCyan.withOpacity(0.3),
                width: 1,
              ),
            ),
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}

