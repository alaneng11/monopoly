import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/game_models.dart';
import '../../../presentation/game_session_controller.dart';

/// پەڕەی بەڕێوەبردنی موڵکەکان — بەرزکردنەوە، بارمتە، فرۆشتن.
class PropertyManagementSheet extends ConsumerWidget {
  final GameState game;
  final String playerId;
  final bool canManage;

  const PropertyManagementSheet({
    super.key,
    required this.game,
    required this.playerId,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameSessionProvider.notifier);
    final owner = game.playerById(playerId)!;
    final owned = game.playerProperties(playerId);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        gradient: AppColors.royalBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.gold, size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text('موڵکەکانی ${owner.name}', style: AppTextStyles.h3)),
                const SizedBox(width: 10),
                Text('${owner.cash} 💰', style: AppTextStyles.titleMedium.copyWith(color: AppColors.goldBright)),
                const SizedBox(width: 8),
                CircleIconButton(icon: Icons.close, size: 38, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
          Flexible(
            child: owned.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text('هیچ موڵکێک نییە — لە ڕیزی خۆتدا خانە بکڕە!', style: AppTextStyles.bodySoft, textAlign: TextAlign.center),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: owned.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final ts = owned[i];
                      final def = game.board[ts.tileIndex];
                      final groupColor = def.group >= 0 ? AppColors.propertyGroups[def.group % AppColors.propertyGroups.length] : AppColors.gold;
                      final upgradeCost = game.activeEvent?.type == GameEventType.construction
                          ? (def.upgradeCost * 0.5).round()
                          : def.upgradeCost;
                      final canUpgrade = canManage &&
                          !ts.mortgaged &&
                          ts.level < def.maxLevel &&
                          !def.isStation &&
                          owner.cash >= upgradeCost;
                      return GlassContainer(
                        borderRadius: 18,
                        padding: const EdgeInsets.all(12),
                        borderColor: ts.mortgaged ? AppColors.danger.withValues(alpha: 0.4) : groupColor.withValues(alpha: 0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 30,
                                  decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(def.name, style: AppTextStyles.titleMedium.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Row(
                                        children: [
                                          ...List.generate(5, (li) => Padding(
                                                padding: const EdgeInsets.only(left: 2),
                                                child: Icon(
                                                  li < ts.level ? Icons.cottage : Icons.cottage_outlined,
                                                  size: 12,
                                                  color: li < ts.level ? AppColors.goldBright : Colors.white24,
                                                ),
                                              )),
                                          const SizedBox(width: 8),
                                          Text('کرێ: ${def.rentAtLevel(ts.level)}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                                          if (ts.mortgaged) ...[
                                            const SizedBox(width: 8),
                                            const Icon(Icons.lock, size: 10, color: AppColors.danger),
                                            Text(' بارمتە', style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.danger)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (ts.level < def.maxLevel && !def.isStation)
                                    Expanded(
                                      child: _ActionBtn(
                                        label: 'بەرزکردنەوە ($upgradeCost)',
                                        icon: Icons.arrow_upward_rounded,
                                        color: AppColors.success,
                                        enabled: canUpgrade,
                                        onTap: () {
                                          Navigator.pop(context);
                                          controller.upgradeTile(def.index);
                                        },
                                      ),
                                    ),
                                  if (ts.level < def.maxLevel && !def.isStation) const SizedBox(width: 6),
                                  Expanded(
                                    child: ts.mortgaged
                                        ? _ActionBtn(
                                            label: 'لابردنی بارمتە (${(def.price ~/ 2 * 1.1).round()})',
                                            icon: Icons.lock_open,
                                            color: AppColors.info,
                                            enabled: owner.cash >= (def.price ~/ 2 * 1.1).round(),
                                            onTap: () {
                                              Navigator.pop(context);
                                              controller.unmortgageTile(def.index);
                                            },
                                          )
                                        : _ActionBtn(
                                            label: 'بارمتە (${def.price ~/ 2})',
                                            icon: Icons.lock,
                                            color: AppColors.amethyst,
                                            enabled: ts.level == 0,
                                            onTap: () {
                                              Navigator.pop(context);
                                              controller.mortgageTile(def.index);
                                            },
                                          ),
                                  ),
                                  const SizedBox(width: 6),
                                  _ActionBtn(
                                    label: 'فرۆشتن',
                                    icon: Icons.sell,
                                    color: AppColors.danger,
                                    enabled: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      controller.sellTile(def.index);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.icon, required this.color, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
