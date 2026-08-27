import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/game_models.dart';

/// پردی گواستنەوەی Pass & Play — شاردنەوەی زانیاری هەستیار و
/// داوای گواستنەوەی مۆبایل بۆ یاریزانی داهاتوو.
/// بە شێوەی تەواو داپۆشراو (opaque) نیشان دەدرێت بۆ شاردنەوەی تەختە.
class HandoffOverlay extends StatelessWidget {
  final Player nextPlayer;
  final int playerNumber;
  final int totalHumans;
  final VoidCallback onConfirm;

  const HandoffOverlay({
    super.key,
    required this.nextPlayer,
    required this.onConfirm,
    this.playerNumber = 1,
    this.totalHumans = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.night,
      child: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phonelink, color: AppColors.gold, size: 34),
                  const SizedBox(height: 10),
                  Text('گواستنەوەی مۆبایل', style: AppTextStyles.caption),
                  const SizedBox(height: 22),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [nextPlayer.color.withValues(alpha: 0.9), nextPlayer.color.withValues(alpha: 0.5)],
                      ),
                      border: Border.all(color: AppColors.goldBright, width: 3),
                      boxShadow: AppColors.goldGlow(blur: 30),
                    ),
                    child: Center(
                      child: Text(
                        nextPlayer.name.isEmpty ? '؟' : nextPlayer.name.substring(0, 1),
                        style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('ڕیزی تۆیە', style: AppTextStyles.h3.copyWith(color: AppColors.parchment)),
                  const SizedBox(height: 4),
                  Text(
                    nextPlayer.name,
                    style: AppTextStyles.display.copyWith(color: AppColors.goldBright),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  GlassContainer(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off, color: AppColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'زانیارییەکان شاراوەن — پارە و موڵکەکان',
                          style: AppTextStyles.caption.copyWith(color: AppColors.parchment),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'یاریزانی $playerNumber لە $totalHumans',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: GoldenButton(
                      label: 'من ${nextPlayer.name}م — دەستپێبکە',
                      icon: Icons.play_arrow_rounded,
                      height: 58,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onConfirm();
                      },
                    ),
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
