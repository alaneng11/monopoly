import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// داسێکی ئەنیمەیشن‌دار — گوشین دەیخوڵقێنێت و ژمارەیەکی هەڕەمەکی پیشان دەدات.
class AnimatedDice extends StatefulWidget {
  final int result;
  final VoidCallback? onRoll;
  final double size;
  final bool rolling;

  const AnimatedDice({
    super.key,
    required this.result,
    this.onRoll,
    this.size = 84,
    this.rolling = false,
  });

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _displayValue = 1;

  @override
  void didUpdateWidget(covariant AnimatedDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rolling && !oldWidget.rolling) {
      _controller.forward(from: 0);
    }
    _displayValue = widget.result;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onRoll,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final angle = sin(t * pi * 6) * (1 - t) * 0.8;
          final bounce = -sin(t * pi) * 18;
          return Transform.translate(
            offset: Offset(0, bounce),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(widget.size * 0.24),
            boxShadow: AppColors.goldGlow(blur: 20),
            border: Border.all(color: AppColors.ivory.withValues(alpha: 0.6), width: 2),
          ),
          padding: EdgeInsets.all(widget.size * 0.14),
          child: _DiceFace(value: _displayValue),
        ),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  const _DiceFace({required this.value});

  static const Map<int, List<Alignment>> _pips = {
    1: [Alignment.center],
    2: [Alignment.topLeft, Alignment.bottomRight],
    3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
    4: [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight],
    5: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.center,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
    6: [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _pips[value.clamp(1, 6)]!;
    return Stack(
      children: pips
          .map((a) => Align(
                alignment: a,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.night,
                    shape: BoxShape.circle,
                  ),
                ),
              ))
          .toList(),
    );
  }
}
