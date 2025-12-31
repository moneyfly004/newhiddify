import 'package:flutter/material.dart';
import '../../../core/models/connection_mode.dart';

/// 模式选择器组件
class ModeSelector extends StatefulWidget {
  final ConnectionMode currentMode;
  final ValueChanged<ConnectionMode> onModeChanged;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  State<ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends State<ModeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ModeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final targetValue = widget.currentMode == ConnectionMode.rules ? 0.0 : 1.0;
    _animationController.animateTo(targetValue);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // 滑动指示器
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width - 32;
              final indicatorWidth = (width - 8) / 2;
              final left = _animation.value * indicatorWidth + 4;

              return Positioned(
                left: left,
                top: 4,
                bottom: 4,
                child: Container(
                  width: indicatorWidth,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
          // 按钮
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  context,
                  ConnectionMode.rules,
                  Icons.rule,
                  '规则',
                ),
              ),
              Expanded(
                child: _buildModeButton(
                  context,
                  ConnectionMode.global,
                  Icons.public,
                  '全局',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    ConnectionMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = widget.currentMode == mode;

    return InkWell(
      onTap: () => widget.onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

