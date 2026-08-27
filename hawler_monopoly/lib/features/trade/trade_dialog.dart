import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/game_models.dart';

/// پەڕەی بازرگانی — پێشنیازی پارە و موڵک لە هەردوو لایەن.
class TradeDialogSheet extends StatefulWidget {
  final GameState game;
  final String currentId;

  const TradeDialogSheet({super.key, required this.game, required this.currentId});

  @override
  State<TradeDialogSheet> createState() => _TradeDialogSheetState();
}

class _TradeDialogSheetState extends State<TradeDialogSheet> {
  late final List<Player> _targets =
      widget.game.players.where((p) => p.id != widget.currentId && !p.bankrupt).toList();
  Player? _partner;
  int _myMoney = 0;
  int _theirMoney = 0;
  final Set<int> _myTiles = {};
  final Set<int> _theirTiles = {};

  @override
  Widget build(BuildContext context) {
    final me = widget.game.playerById(widget.currentId)!;
    final partner = _partner;
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
                const Icon(Icons.handshake_rounded, color: AppColors.gold, size: 24),
                const SizedBox(width: 10),
                Text('بازرگانی', style: AppTextStyles.h3),
                const Spacer(),
                CircleIconButton(icon: Icons.close, size: 38, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('یاریزانی بەرامبەر', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _targets.map((p) {
                      final selected = _partner?.id == p.id;
                      return GestureDetector(
                        onTap: () => setState(() => _partner = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: selected ? AppColors.goldButton : null,
                            color: selected ? null : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? AppColors.gold : AppColors.glassBorder),
                          ),
                          child: Text(p.name,
                              style: AppTextStyles.caption.copyWith(
                                color: selected ? AppColors.night : AppColors.parchment,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _sidePanel(me, _myMoney, _myTiles, (v) => setState(() => _myMoney = v), (i) => setState(() => _myTiles.contains(i) ? _myTiles.remove(i) : _myTiles.add(i)))),
                      const SizedBox(width: 10),
                      const Column(
                        children: [
                          Icon(Icons.swap_horiz, color: AppColors.gold, size: 26),
                        ],
                      ),
                      const SizedBox(width: 10),
                      if (partner != null)
                        Expanded(child: _sidePanel(partner, _theirMoney, _theirTiles, (v) => setState(() => _theirMoney = v), (i) => setState(() => _theirTiles.contains(i) ? _theirTiles.remove(i) : _theirTiles.add(i))))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GoldenButton(
              label: 'ناردنی پێشنیاز',
              icon: Icons.send_rounded,
              height: 52,
              width: double.infinity,
              onTap: partner == null
                  ? null
                  : (_myMoney == 0 && _theirMoney == 0 && _myTiles.isEmpty && _theirTiles.isEmpty)
                      ? null
                      : () {
                          final offer = TradeOffer(
                            id: 'trade_${DateTime.now().millisecondsSinceEpoch}',
                            fromPlayerId: widget.currentId,
                            toPlayerId: partner.id,
                            moneyFrom: _myMoney,
                            moneyTo: _theirMoney,
                            tilesFrom: _myTiles.toList(),
                            tilesTo: _theirTiles.toList(),
                          );
                          Navigator.pop(context, offer);
                        },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidePanel(Player p, int money, Set<int> tiles, ValueChanged<int> onMoney, ValueChanged<int> onTile) {
    final owned = widget.game.playerProperties(p.id);
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p.name} پێشکەش دەکات', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('پارە: $money / ${p.cash}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: AppColors.goldBright,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: money.toDouble(),
              max: p.cash.toDouble().clamp(0, 1 << 20).toDouble(),
              divisions: (p.cash ~/ 25).clamp(1, 400),
              onChanged: (v) => onMoney(v.round()),
            ),
          ),
          if (owned.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...owned.map((ts) {
              final def = widget.game.board[ts.tileIndex];
              final selected = tiles.contains(def.index);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selected ? AppColors.goldBright : AppColors.parchment.withValues(alpha: 0.5),
                  size: 18,
                ),
                title: Text(def.name, style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                subtitle: Text('ئاست ${ts.level}${ts.mortgaged ? ' — بارمتە' : ''}', style: AppTextStyles.caption.copyWith(fontSize: 9)),
                onTap: () => onTile(def.index),
              );
            }),
          ],
        ],
      ),
    );
  }
}
