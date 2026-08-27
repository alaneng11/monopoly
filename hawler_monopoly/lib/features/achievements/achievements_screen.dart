import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

class _Def {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final int reward;
  const _Def(this.id, this.title, this.desc, this.icon, this.reward);
}

/// دەستکەوتەکان — بەستراوە بە پاشەکەوتی ڕاستەقینە.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  static const _items = [
    _Def('first_claim', 'دەستپێکی ڕۆژانە', 'یەکەم خەڵاتی ڕۆژانە وەربگرە', Icons.card_giftcard, 100),
    _Def('first_win', 'یەکەم سەرکەوتن', 'یەکەم یاری ببەرەوە', Icons.emoji_events, 500),
    _Def('monopoly', 'خاوەنی گەڕەک', 'هەموو خانەکانی یەک ڕەنگ بکڕە', Icons.castle, 400),
    _Def('landmark', 'شوێنی گرنگ', 'قەڵای هەولێر بکڕیت', Icons.location_city, 600),
    _Def('trader', 'بازرگان', 'یەکەم بازرگانی تەواو بکە', Icons.handshake, 250),
    _Def('rich', 'زەنگین', 'دەگاتە ١٠٠٠٠ سامان', KurdishIcons.coin, 800),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(achievementsProvider).value ?? const <String>[];
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
                    Text('ئەفتخاراتەکان', style: AppTextStyles.h2),
                    const Spacer(),
                    Text('${unlocked.length}/${_items.length}', style: AppTextStyles.goldLabel),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = _items[i];
                    final done = unlocked.contains(a.id);
                    return FadeInUp(
                      delay: Duration(milliseconds: 60 * i),
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(16),
                        borderColor: done ? AppColors.gold.withValues(alpha: 0.5) : AppColors.glassBorder,
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: done ? AppColors.goldGradient : null,
                                color: done ? null : Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(a.icon, color: done ? AppColors.night : AppColors.gold, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(a.desc, style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(done ? Icons.check_circle : KurdishIcons.coin,
                                color: done ? AppColors.success : AppColors.gold, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
