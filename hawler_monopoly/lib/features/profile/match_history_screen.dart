import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

/// شاشەی تۆماری یارییەکان — نیشاندانی ئەنجامی یارییەکانی تێکراوە.
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(matchHistoryProvider).value ?? const <Map<String, dynamic>>[];

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
                    Text('تۆماری یارییەکان', style: AppTextStyles.h2),
                    const Spacer(),
                    Text('${history.length} یاری', style: AppTextStyles.goldLabel),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (history.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, color: AppColors.gold.withValues(alpha: 0.4), size: 60),
                        const SizedBox(height: 16),
                        Text('هیچ یاریێک تەواونەبووە', style: AppTextStyles.bodySoft),
                        const SizedBox(height: 8),
                        Text('یارییەک ببە و ئەنجامەکان لێرەدا دەبن', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final match = history[i];
                      return FadeInUp(
                        delay: Duration(milliseconds: 40 * i),
                        child: _matchCard(match, i + 1),
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

  Widget _matchCard(Map<String, dynamic> match, int rank) {
    final winnerName = match['winnerName'] as String? ?? '';
    final playerNames = (match['playerNames'] as List?)?.cast<String>() ?? [];
    final round = match['round'] as int? ?? 1;
    final duration = match['durationSeconds'] as int? ?? 0;
    final propertiesOwned = match['propertiesOwned'] as int? ?? 0;
    final tradesCompleted = match['tradesCompleted'] as int? ?? 0;
    final diceRolled = match['diceRolled'] as int? ?? 0;
    final finalNetWorth = match['finalNetWorth'] as int? ?? 0;
    final playedAt = match['playedAt'] as int? ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(playedAt);

    final durationMin = (duration / 60).floor();
    final durationSec = duration % 60;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      borderColor: rank == 1 ? AppColors.gold.withValues(alpha: 0.5) : AppColors.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: rank == 1 ? AppColors.goldGradient : null,
                  color: rank == 1 ? null : AppColors.glassFill,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                    style: TextStyle(fontSize: rank <= 3 ? 22 : 16,
                      color: rank > 3 ? AppColors.parchment : null),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بردنەوە: $winnerName',
                      style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${playerNames.join(" • ")}',
                      style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_formatDate(date)}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                  Text('$durationMin:${durationSec.toString().padLeft(2, '0')}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _statChip('دۆرە $round', Icons.replay_circle_filled),
              _statChip('$propertiesOwned موڵک', Icons.home),
              _statChip('$tradesCompleted بازرگانی', Icons.handshake),
              _statChip('$diceRolled داودان', Icons.casino),
              _statChip('$finalNetWorth 💰', KurdishIcons.coin),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.gold.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(text, style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }
}
