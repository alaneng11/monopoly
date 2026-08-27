import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/game_models.dart';

/// دیالۆگی پیشاندانی کارتی چانس/ڕووداو بە ئەنیمەیشنی وەرگێڕان.
class GameCardDialog extends StatefulWidget {
  final GameCard card;
  final String playerName;
  final VoidCallback onClose;

  const GameCardDialog({super.key, required this.card, required this.playerName, required this.onClose});

  @override
  State<GameCardDialog> createState() => _GameCardDialogState();
}

class _GameCardDialogState extends State<GameCardDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.card.effect) {
        CardEffect.gainMoney => Icons.card_giftcard,
        CardEffect.loseMoney => Icons.money_off,
        CardEffect.moveTo => Icons.directions_run,
        CardEffect.moveBy => Icons.swap_horiz,
        CardEffect.goToJail => Icons.gavel,
        CardEffect.getOutOfJail => Icons.lock_open,
        CardEffect.repairAll => Icons.build_circle,
        CardEffect.collectFromAll => Icons.volunteer_activism,
        CardEffect.doubleRentNextTurn => Icons.trending_up,
      };

  String get _effectText {
    final c = widget.card;
    switch (c.effect) {
      case CardEffect.gainMoney:
        return c.amount > 0 ? '+${c.amount} 💰' : '';
      case CardEffect.loseMoney:
        return c.amount > 0 ? '-${c.amount} 💰' : '';
      case CardEffect.repairAll:
        return '${c.amount} بۆ هەر بینایەک';
      case CardEffect.collectFromAll:
        return '+${c.amount} لە هەر یاریزانێک';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.card.isEvent ? AppColors.amethyst : AppColors.sapphire;
    final isGood = switch (widget.card.effect) {
      CardEffect.gainMoney => true,
      CardEffect.loseMoney => false,
      CardEffect.goToJail => false,
      CardEffect.moveTo || CardEffect.moveBy || CardEffect.getOutOfJail || CardEffect.collectFromAll => true,
      _ => widget.card.isEvent,
    };
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = (1 - _controller.value) * 3.14;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
            child: child,
          );
        },
        child: GlassContainer(
          borderRadius: 26,
          padding: const EdgeInsets.all(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.5), AppColors.night2.withValues(alpha: 0.9)],
          ),
          borderColor: color.withValues(alpha: 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.card.isEvent ? 'کارتی ڕووداو' : 'کارتی چانس',
                style: AppTextStyles.caption.copyWith(color: color.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 8),
              Icon(_icon, color: AppColors.goldBright, size: 44),
              const SizedBox(height: 12),
              Text(widget.card.title, style: AppTextStyles.h3, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(widget.card.description, style: AppTextStyles.bodySoft, textAlign: TextAlign.center),
              if (_effectText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isGood ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: (isGood ? AppColors.success : AppColors.danger).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _effectText,
                    style: AppTextStyles.titleMedium.copyWith(color: isGood ? AppColors.success : AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text('بۆ: ${widget.playerName}', style: AppTextStyles.caption),
              const SizedBox(height: 20),
              GoldenButton(
                label: 'باشە',
                height: 48,
                width: 160,
                variant: isGood ? ButtonVariant.emerald : ButtonVariant.danger,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
