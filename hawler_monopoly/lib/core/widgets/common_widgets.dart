import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_container.dart';

/// پیلی نیشاندانی دراو/ئەلماس لە سەرووی هەموو شاشەکان.
class CurrencyPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const CurrencyPill({
    super.key,
    required this.icon,
    required this.value,
    this.color = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(value, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

/// چوارچێوەی زێڕین بۆ وێنەی پرۆفایل — بۆ بەکارهێنانی گشتی.
class AvatarRing extends StatelessWidget {
  final double size;
  final String initials;
  final int level;
  const AvatarRing({super.key, this.size = 64, required this.initials, this.level = 1});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.goldGradient,
            boxShadow: AppColors.goldGlow(blur: 16),
          ),
          child: CircleAvatar(
            backgroundColor: AppColors.citadelBrown,
            child: Text(
              initials,
              style: AppTextStyles.h3.copyWith(fontSize: size * 0.32),
            ),
          ),
        ),
        Positioned(
          bottom: -6,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.night, width: 1.5),
              ),
              child: Text('$level', style: AppTextStyles.caption.copyWith(
                color: AppColors.night, fontWeight: FontWeight.w800, fontSize: 10,
              )),
            ),
          ),
        ),
      ],
    );
  }
}

/// سەرناوی بەشەکان لەگەڵ هێڵی زێڕین.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppTextStyles.h3)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!, style: AppTextStyles.goldLabel),
          ),
      ],
    );
  }
}

/// دوگمەی بچووکی دەوری — بۆ back/settings/close هتد.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  const CircleIconButton({super.key, required this.icon, this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: size / 2,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: AppColors.ivory, size: size * 0.45),
        ),
      ),
    );
  }
}

/// نیشانەی ستار بۆ ڕەیتینگ/ئاست.
class GoldDivider extends StatelessWidget {
  final double width;
  const GoldDivider({super.key, this.width = 60});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class KurdishIcons {
  KurdishIcons._();
  static const dice = FontAwesomeIcons.diceD6;
  static const coin = FontAwesomeIcons.coins;
  static const gem = FontAwesomeIcons.gem;
  static const crown = FontAwesomeIcons.crown;
  static const trophy = FontAwesomeIcons.trophy;
}
