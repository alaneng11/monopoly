import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

/// دیالۆگی بەرزکردنەوەی موڵک — زیادکردنی خانوو تا گەیشتن بە هۆتێل.
class UpgradeDialog extends StatefulWidget {
  final String name;
  final Color groupColor;
  final int currentLevel;
  final int upgradeCost;

  const UpgradeDialog({
    super.key,
    required this.name,
    required this.groupColor,
    this.currentLevel = 1,
    this.upgradeCost = 150,
  });

  @override
  State<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  late int level = widget.currentLevel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          borderColor: AppColors.gold.withValues(alpha: 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upgrade_rounded, color: widget.groupColor, size: 36),
              const SizedBox(height: 10),
              Text('بەرزکردنەوەی موڵک', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(widget.name, style: AppTextStyles.bodySoft),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final filled = i < level;
                  return Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: filled ? AppColors.goldGradient : null,
                          color: filled ? null : Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: filled ? AppColors.gold : AppColors.glassBorder),
                        ),
                        child: Icon(
                          i == 4 ? Icons.hotel : Icons.home,
                          size: 16,
                          color: filled ? AppColors.night : Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(i == 4 ? 'هۆتێل' : '${i + 1}', style: AppTextStyles.caption),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 22),
              GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('تێچووی بەرزکردنەوە: ', style: AppTextStyles.bodySoft),
                    const Icon(KurdishIcons.coin, color: AppColors.gold, size: 16),
                    const SizedBox(width: 4),
                    Text('${widget.upgradeCost}', style: AppTextStyles.titleMedium),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GoldenButton(
                      label: 'داخستن',
                      variant: ButtonVariant.glass,
                      height: 50,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoldenButton(
                      label: 'بەرزکردنەوە',
                      height: 50,
                      variant: ButtonVariant.emerald,
                      onTap: level < 5
                          ? () => setState(() => level++)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
