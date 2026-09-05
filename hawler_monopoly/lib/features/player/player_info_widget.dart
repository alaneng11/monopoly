import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/game_models.dart';
import '../../core/widgets/widgets.dart';
import '../board/widgets/player_token.dart';

/// نوارێکی درێژ کە دۆخی ڕاستەقینەی هەموو یاریزانەکان لە یارییەکدا نیشان دەدات.
class PlayerInfoBar extends StatelessWidget {
  final List<Player> players;
  final String? activePlayerId;
  final GamePhase phase;
  final Function(String)? onTap;

  const PlayerInfoBar({
    super.key,
    required this.players,
    this.activePlayerId,
    required this.phase,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _PlayerChip(
            player: players[i],
            isActive: players[i].id == activePlayerId,
            onTap: onTap != null ? () => onTap!(players[i].id) : null,
          ),
        ),
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final Player player;
  final bool isActive;
  final VoidCallback? onTap;

  const _PlayerChip({required this.player, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: player.bankrupt ? 0.4 : 1,
        child: GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          borderColor: isActive ? AppColors.gold : AppColors.glassBorder,
          borderWidth: isActive ? 1.5 : 1,
          shadows: isActive ? AppColors.goldGlow(blur: 10) : AppColors.softShadow(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  PlayerToken(
                    color: player.color,
                    icon: player.character.icon,
                    size: 30,
                    isActive: isActive,
                  ),
                  if (player.inJail)
                    const Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(Icons.lock, size: 12, color: AppColors.danger),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          player.name,
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (player.isAi) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.smart_toy_outlined, size: 10, color: AppColors.info),
                      ],
                      if (player.bankrupt) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.close, size: 10, color: AppColors.danger),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(KurdishIcons.coin, size: 10, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text('${player.cash}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      const SizedBox(width: 8),
                      const Icon(Icons.home_outlined, size: 10, color: AppColors.parchment),
                      const SizedBox(width: 3),
                      Text('${player.propertiesOwned}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ],
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
