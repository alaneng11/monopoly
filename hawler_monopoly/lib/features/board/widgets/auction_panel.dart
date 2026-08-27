import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';

/// پانێڵی مزایەدە — نرخی ئێستا، بەرزترین بیدەر، و دوگمەکانی پیشنهاد.
class AuctionPanel extends StatelessWidget {
  final String propertyName;
  final int highestBid;
  final String? highestBidder;
  final int myCash;
  final bool canBid;
  final ValueChanged<int> onBid;
  final VoidCallback onPass;

  const AuctionPanel({
    super.key,
    required this.propertyName,
    required this.highestBid,
    required this.highestBidder,
    required this.myCash,
    required this.canBid,
    required this.onBid,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    final nextMin = highestBid + 10;
    final options = [nextMin, nextMin + 20, nextMin + 50].where((v) => v <= myCash).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.amethyst.withValues(alpha: 0.35), AppColors.night2.withValues(alpha: 0.9)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: AppColors.softShadow(blur: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel, color: AppColors.goldBright, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('مزایەدە: $propertyName', style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('$highestBid', style: AppTextStyles.titleMedium.copyWith(color: AppColors.goldBright)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              highestBidder == null ? 'هیچ بیدێک نییە' : 'بەرزترین بیدەر: $highestBidder',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: 10),
          if (canBid)
            Row(
              children: [
                Expanded(
                  child: GoldenButton(
                    label: 'کشاندنەوە',
                    height: 44,
                    fontSize: 13,
                    variant: ButtonVariant.glass,
                    onTap: onPass,
                  ),
                ),
                const SizedBox(width: 8),
                ...options.map((v) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GoldenButton(
                        label: '$v',
                        height: 44,
                        fontSize: 13,
                        variant: ButtonVariant.emerald,
                        width: 76,
                        onTap: () => onBid(v),
                      ),
                    )),
              ],
            )
          else
            Text('چاوەڕوانی بیدەرەکان...', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
