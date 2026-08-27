import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/game_models.dart';
import '../../data/game/hawler_board.dart';
import '../../presentation/game_session_controller.dart';

/// شاشەی کۆگای موڵکەکان — پێشکەوتنی گروپەکان و بەخشینەکان.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final game = session.game;

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
                    Text('کۆگای موڵکەکان', style: AppTextStyles.h2),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: PropertyCollection.all.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final col = PropertyCollection.all[i];
                    final board = game?.board ?? HawlerBoard.build();
                    final tiles = game?.tiles ?? <int, TileState>{};

                    // ژمارەی خانەکانی ئەم گروپە لە تەختە
                    final groupTiles = board.where((t) => t.type == TileType.property && t.group == col.groupId).toList();
                    final totalInGroup = groupTiles.length;
                    // ژمارەی خانەکانی تەواو کڕاوە
                    final ownedInGroup = groupTiles.where((t) {
                      final ts = tiles[t.index];
                      return ts != null && ts.ownerId != null;
                    }).length;
                    final completed = totalInGroup > 0 && ownedInGroup >= totalInGroup;
                    final percent = totalInGroup > 0 ? ownedInGroup / totalInGroup : 0.0;

                    return FadeInUp(
                      delay: Duration(milliseconds: 50 * i),
                      child: GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(16),
                        borderColor: completed ? col.groupColor.withValues(alpha: 0.6) : AppColors.glassBorder,
                        shadows: completed ? [
                          BoxShadow(color: col.groupColor.withValues(alpha: 0.3), blurRadius: 14)
                        ] : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [col.groupColor, col.groupColor.withValues(alpha: 0.6)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(col.nameKu,
                                              style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                                          ),
                                          if (completed)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                              ),
                                              child: Text('تەواوبوو! ✓',
                                                style: AppTextStyles.caption.copyWith(
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(col.descriptionKu, style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // پڕۆگرەس
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 8,
                                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                                      color: completed ? AppColors.success : col.groupColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('$ownedInGroup / $totalInGroup',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // بەخشینەکان
                            Row(
                              children: [
                                _bonusChip('${col.bonusCoins} 💰', AppColors.gold),
                                const SizedBox(width: 6),
                                _bonusChip('${col.bonusDice} ⚡', AppColors.info),
                                const SizedBox(width: 6),
                                _bonusChip('${col.bonusXp} XP', AppColors.emerald),
                                if (col.rentMultiplier > 1.0) ...[
                                  const SizedBox(width: 6),
                                  _bonusChip('کرێ ×${col.rentMultiplier}', AppColors.ruby),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bonusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
