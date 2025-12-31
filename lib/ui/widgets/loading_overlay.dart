import 'package:flutter/material.dart';
import '../../ui/theme/cyberpunk_theme.dart';

/// 加载遮罩组件
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: CyberpunkTheme.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CyberpunkTheme.neonCyan,
                    width: 1,
                  ),
                  boxShadow: CyberpunkTheme.neonGlow(CyberpunkTheme.neonCyan),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CyberpunkTheme.neonCyan,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

