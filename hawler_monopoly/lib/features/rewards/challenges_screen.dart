import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/game_models.dart';
import '../../presentation/providers.dart';

/// شاشەی داواکارییەکان — پێشکەوتنی ڕۆژانە و هەفتانە بە بەخشینی ڕاستەقینە.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(challengeProvider).value ?? const ChallengeProgress({});

    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 12),
                    Text('داواکارییەکان', style: AppTextStyles.h2),
                    const Spacer(),
                    CurrencyPill(icon: KurdishIcons.coin, value: '${ref.watch(profileProvider).value?.coins ?? 0}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // تابی ڕۆژانە / هەفتانە
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _tab == 0 ? AppColors.goldGradient : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('ڕۆژانە', textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: _tab == 0 ? AppColors.night : AppColors.parchment,
                                fontWeight: FontWeight.w700,
                              )),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              gradient: _tab == 1 ? AppColors.goldGradient : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text('هەفتانە', textAlign: TextAlign.center,
                              style: AppTextStyles.caption.copyWith(
                                color: _tab == 1 ? AppColors.night : AppColors.parchment,
                                fontWeight: FontWeight.w700,
                              )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _tab == 0
                    ? _challengeList(Challenge.daily, progress, false)
                    : _challengeList(Challenge.weekly, progress, true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _challengeList(List<Challenge> challenges, ChallengeProgress progress, bool isWeekly) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: challenges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final ch = challenges[i];
        final currentProgress = progress.getProgress(ch.id);
        final completed = currentProgress >= ch.target;
        final percent = (currentProgress / ch.target).clamp(0.0, 1.0);

        return FadeInUp(
          delay: Duration(milliseconds: 50 * i),
          child: GestureDetector(
            onTap: completed ? () => _claimReward(ch, isWeekly) : null,
            child: GlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              borderColor: completed ? AppColors.gold.withValues(alpha: 0.6) : AppColors.glassBorder,
              shadows: completed ? AppColors.goldGlow(blur: 14) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: completed ? AppColors.goldGradient : null,
                          color: completed ? null : AppColors.propertyGroups[i % 8].withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(ch.icon, color: completed ? AppColors.night : AppColors.propertyGroups[i % 8], size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ch.titleKu, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(ch.descriptionKu, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      if (completed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                          ),
                          child: Text('تەواوبوو!', style: AppTextStyles.caption.copyWith(
                            color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // پڕۆگرەسی بار
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percent.toDouble(),
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            color: completed ? AppColors.success : AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$currentProgress / ${ch.target}',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: completed ? AppColors.success : AppColors.parchment)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // بەخشینەکان
                  Row(
                    children: [
                      _rewardPill('${ch.bonusCoins} 💰', AppColors.gold),
                      const SizedBox(width: 8),
                      _rewardPill('${ch.bonusDice} ⚡', AppColors.info),
                      const SizedBox(width: 8),
                      _rewardPill('${ch.bonusXp} XP', AppColors.emerald),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rewardPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }

  void _claimReward(Challenge ch, bool isWeekly) {
    // پاشەکەوتکردنی بەخشین
    ref.read(profileProvider.notifier).addCoins(ch.bonusCoins);
    ref.read(achievementsProvider.notifier).unlock(ch.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('بەخشینی "${ch.titleKu}" وەرگیرا! +${ch.bonusCoins} 💰 +${ch.bonusXp} XP')),
    );
    // ڕیستکردنی پێشکەوتن
    ref.read(challengeProvider.notifier).resetDaily();
  }
}
