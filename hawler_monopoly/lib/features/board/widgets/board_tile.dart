import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum TileType { property, corner, chance, event, tax, station }

/// خانەیەکی تەختەی یاری — ڕەنگی گروپ، نیشانەی بینا بەپێی ئاست،
/// ڕەنگی خاوەن و دۆخی بارمتە.
class BoardTile extends StatelessWidget {
  final String name;
  final TileType type;
  final Color? groupColor;
  final int? price;
  final IconData? icon;
  final bool owned;
  final Color? ownerColor;
  final bool rotated;
  final int level;
  final bool mortgaged;

  const BoardTile({
    super.key,
    required this.name,
    this.type = TileType.property,
    this.groupColor,
    this.price,
    this.icon,
    this.owned = false,
    this.ownerColor,
    this.rotated = false,
    this.level = 0,
    this.mortgaged = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = groupColor ?? AppColors.terracotta;
    final accentTint = owned ? (ownerColor ?? AppColors.gold) : accent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 42 || constraints.maxHeight < 42;
        final labelStyle = AppTextStyles.tileLabel.copyWith(
          fontSize: compact ? 4.8 : 7.3,
          height: 0.9,
          color: AppColors.ivory,
        );

        final tileBody = Container(
          decoration: BoxDecoration(
            gradient: type == TileType.corner
                ? LinearGradient(
                    colors: [
                      AppColors.citadelBrown.withValues(alpha: 0.97),
                      AppColors.night2.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      AppColors.night2.withValues(alpha: 0.97),
                      AppColors.night.withValues(alpha: 0.96),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: owned ? accentTint.withValues(alpha: 0.85) : AppColors.glassBorder,
              width: owned ? 1.6 : 1.0,
            ),
            borderRadius: BorderRadius.circular(type == TileType.corner ? 10 : 8),
            boxShadow: owned
                ? [
                    BoxShadow(
                      color: accentTint.withValues(alpha: 0.28),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.night.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  if (type == TileType.property || type == TileType.station)
                    Container(
                      height: compact ? 9 : 14,
                      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(compact ? 6 : 7)),
                      ),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 2,
                          runSpacing: 0,
                          children: [
                            if (level > 0)
                              ...List.generate(
                                level > 5 ? 5 : level,
                                (_) => Icon(Icons.business, size: compact ? 5 : 7, color: Colors.white.withValues(alpha: 0.95)),
                              ),
                            if (owned && level == 0)
                              Container(
                                width: compact ? 5 : 6,
                                height: compact ? 5 : 6,
                                decoration: BoxDecoration(
                                  color: ownerColor ?? AppColors.goldBright,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3, vertical: compact ? 2 : 4),
                      child: LayoutBuilder(
                        builder: (context, inner) {
                          final children = <Widget>[];
                          if (icon != null) {
                            children.add(
                              Icon(
                                icon,
                                size: compact ? 7.5 : (type == TileType.corner ? 16 : 11),
                                color: type == TileType.corner ? AppColors.goldBright : AppColors.gold,
                              ),
                            );
                          }

                          if (name.isNotEmpty) {
                            children.add(
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: labelStyle,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (price != null && !compact) {
                            children.add(
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: inner.maxWidth * 0.9),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.night.withValues(alpha: 0.38),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
                                    ),
                                    child: Text(
                                      '$price',
                                      style: AppTextStyles.tileLabel.copyWith(fontSize: compact ? 4.2 : 6.7, color: AppColors.goldBright),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: children,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (mortgaged)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.night.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.lock_outline_rounded, size: compact ? 12 : 16, color: AppColors.danger),
                ),
              if (level >= 5)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(Icons.workspace_premium_rounded, size: compact ? 8 : 10, color: AppColors.goldBright),
                ),
            ],
          ),
        );

        final content = rotated ? RotatedBox(quarterTurns: 1, child: tileBody) : tileBody;
        return content;
      },
    );
  }
}
