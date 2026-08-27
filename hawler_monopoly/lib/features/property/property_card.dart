import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

/// کارتی نیشاندانی موڵک بۆ بەکارهێنان لە کۆگا/پرۆفایل/دیالۆگەکان.
class PropertyCard extends StatelessWidget {
  final String name;
  final Color groupColor;
  final int price;
  final int rent;
  final int level; // 0 = بێ بینا، 1-4 = خانوو، 5 = هۆتێل
  final bool owned;

  const PropertyCard({
    super.key,
    required this.name,
    required this.groupColor,
    required this.price,
    this.rent = 0,
    this.level = 0,
    this.owned = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: double.infinity,
            decoration: BoxDecoration(
              color: groupColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(
                    i < level ? Icons.home : Icons.home_outlined,
                    size: 14,
                    color: i < level ? AppColors.goldBright : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(KurdishIcons.coin, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text('نرخ: $price', style: AppTextStyles.caption),
                    const SizedBox(width: 12),
                    if (rent > 0) ...[
                      const Icon(Icons.payments_outlined, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('کرێ: $rent', style: AppTextStyles.caption),
                    ],
                  ],
                ),
                if (owned) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Text('خاوەنی تۆیت', textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
