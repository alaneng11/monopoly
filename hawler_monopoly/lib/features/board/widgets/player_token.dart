import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// پارچەی یاریزان (پیاسە) لەگەڵ کاراکتەر و ئەنیمەیشنی بزین.
class PlayerToken extends StatefulWidget {
  final Color color;

  /// ئایکۆنی کاراکتەر. پێشتر ئیمۆجی بەکاردەهێنرا، بەڵام CanvasKit فۆنتی
  /// ئیمۆجی لەخۆ ناگرێت و وەک چوارگۆشەی بەتاڵ (tofu) پیشان دەدرا.
  final IconData icon;
  final double size;
  final bool isActive;

  const PlayerToken({
    super.key,
    required this.color,
    required this.icon,
    this.size = 22,
    this.isActive = false,
  });

  @override
  State<PlayerToken> createState() => _PlayerTokenState();
}

class _PlayerTokenState extends State<PlayerToken> with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (context, child) {
        final bounce = widget.isActive ? math.sin(_idle.value * math.pi) * 1.5 : 0.0;
        final scale = widget.isActive ? 1.0 + _idle.value * 0.04 : 1.0;
        return Transform.translate(
          offset: Offset(0, -bounce),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [widget.color.withValues(alpha: 0.95), widget.color.withValues(alpha: 0.75)],
            center: Alignment.topLeft,
          ),
          shape: BoxShape.circle,
          border: Border.all(color: widget.isActive ? AppColors.goldBright : AppColors.ivory, width: widget.isActive ? 2 : 1.4),
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: 0.55), blurRadius: widget.isActive ? 9 : 5, spreadRadius: 0.5),
            const BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          widget.icon,
          size: widget.size * 0.54,
          color: Colors.white,
        ),
      ),
    );
  }
}
