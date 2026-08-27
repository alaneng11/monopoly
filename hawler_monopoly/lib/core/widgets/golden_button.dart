import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum ButtonVariant { gold, emerald, glass, danger }

/// دوگمەی سەرەکی — گرادیێنتی زێڕین لەگەڵ ئەنیمەیشنی گوشین و تروسکایی.
class GoldenButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ButtonVariant variant;
  final double height;
  final double? width;
  final double fontSize;

  const GoldenButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.variant = ButtonVariant.gold,
    this.height = 56,
    this.width,
    this.fontSize = 16,
  });

  @override
  State<GoldenButton> createState() => _GoldenButtonState();
}

class _GoldenButtonState extends State<GoldenButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.06,
  );

  Gradient get _gradient {
    switch (widget.variant) {
      case ButtonVariant.gold:
        return AppColors.goldButton;
      case ButtonVariant.emerald:
        return AppColors.emeraldButton;
      case ButtonVariant.danger:
        return const LinearGradient(
          colors: [Color(0xFFE0435A), Color(0xFF9E2436)],
        );
      case ButtonVariant.glass:
        return LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.06)],
        );
    }
  }

  Color get _textColor =>
      widget.variant == ButtonVariant.glass ? AppColors.ivory : AppColors.night;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _controller.forward(),
      onTapUp: disabled ? null : (_) => _controller.reverse(),
      onTapCancel: disabled ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1 - _controller.value,
          child: child,
        ),
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: Container(
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(widget.height / 2),
              boxShadow: widget.variant == ButtonVariant.gold
                  ? AppColors.goldGlow(blur: 18)
                  : AppColors.softShadow(blur: 14),
              border: widget.variant == ButtonVariant.glass
                  ? Border.all(color: AppColors.glassBorder)
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: _textColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: AppTextStyles.button.copyWith(
                      color: _textColor,
                      fontSize: widget.fontSize,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
