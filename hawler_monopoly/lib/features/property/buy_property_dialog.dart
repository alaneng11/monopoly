import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

/// دیالۆگی کڕینی موڵک لەگەڵ زانیاری تەواو و کرێی چاوەڕوانکراو.
class BuyPropertyDialog extends StatelessWidget {
  final String name;
  final int price;
  final Color groupColor;
  final int cash;
  final int rent;
  final bool isStation;
  final VoidCallback onBuy;
  final VoidCallback onDecline;

  const BuyPropertyDialog({
    super.key,
    required this.name,
    required this.price,
    required this.groupColor,
    required this.cash,
    required this.onBuy,
    required this.onDecline,
    this.rent = 0,
    this.isStation = false,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = cash >= price;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.all(0),
        borderColor: AppColors.gold.withValues(alpha: 0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [groupColor.withValues(alpha: 0.9), groupColor.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Icon(isStation ? Icons.electric_bolt : Icons.location_city, color: Colors.white, size: 38),
                  const SizedBox(height: 6),
                  Text('موڵکێکی نوێ!', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Text(name, style: AppTextStyles.h2, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(canAfford ? 'دەتەوێت ئەم موڵکە بکڕیت؟' : 'دراوی بەس نییە — دەچێتە مزایەدە',
                      style: AppTextStyles.bodySoft),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text('نرخ', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(KurdishIcons.coin, color: AppColors.gold, size: 16),
                                  const SizedBox(width: 4),
                                  Text('$price', style: AppTextStyles.titleMedium.copyWith(color: AppColors.goldBright)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(isStation ? 'کرێ (١ گاراژ)' : 'کرێی بنەڕەت', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Text('$rent', style: AppTextStyles.titleMedium.copyWith(color: AppColors.success)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text('دراوی تۆ', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Text('$cash', style: AppTextStyles.titleMedium.copyWith(
                                color: canAfford ? AppColors.success : AppColors.danger,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GoldenButton(
                          label: 'مزایەدە',
                          variant: ButtonVariant.glass,
                          height: 50,
                          icon: Icons.gavel,
                          onTap: onDecline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GoldenButton(
                          label: 'بیکڕە',
                          height: 50,
                          icon: Icons.shopping_bag,
                          variant: ButtonVariant.emerald,
                          onTap: canAfford ? onBuy : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
