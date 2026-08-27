import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _tab = 0;
  final tabs = const ['دراو', 'ستایل', 'پارچە یاری'];

  @override
  Widget build(BuildContext context) {
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
                    Text('بازاڕ', style: AppTextStyles.h2),
                    const Spacer(),
                    const CurrencyPill(icon: KurdishIcons.gem, value: '86', color: AppColors.sapphire),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _tabBar(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: ResponsiveCenter(child: _tab == 0 ? _coinPacks() : _itemGrid()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBar() {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.goldGradient : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? AppColors.night : AppColors.parchment,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _coinPacks() {
    final packs = [
      (1000, '٩٩٩ د', false),
      (5500, '٤٬٩٩٩ د', true),
      (12000, '٩٬٩٩٩ د', false),
      (30000, '١٩٬٩٩٩ د', false),
    ];
    return Column(
      children: packs
          .asMap()
          .entries
          .map((e) => FadeInUp(
                delay: Duration(milliseconds: 60 * e.key),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _packTile(e.value.$1, e.value.$2, e.value.$3),
                ),
              ))
          .toList(),
    );
  }

  Widget _packTile(int coins, String priceLabel, bool popular) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      borderColor: popular ? AppColors.gold : AppColors.glassBorder,
      shadows: popular ? AppColors.goldGlow(blur: 14) : AppColors.softShadow(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(KurdishIcons.coin, color: AppColors.night, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$coins زێڕ', style: AppTextStyles.titleMedium),
                    if (popular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.ruby,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('باشترین', style: AppTextStyles.caption.copyWith(fontSize: 10, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                Text('پاکێجی زێڕ', style: AppTextStyles.caption),
              ],
            ),
          ),
          GoldenButton(label: priceLabel, height: 40, fontSize: 12, onTap: () {}),
        ],
      ),
    );
  }

  Widget _itemGrid() {
    final icons = [
      FontAwesomeIcons.hatCowboy,
      FontAwesomeIcons.crown,
      FontAwesomeIcons.chessKnight,
      FontAwesomeIcons.paintbrush,
      FontAwesomeIcons.gem,
      FontAwesomeIcons.wandMagicSparkles,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) => FadeInUp(
        delay: Duration(milliseconds: 50 * i),
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.propertyGroups[i % 8].withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icons[i], color: AppColors.propertyGroups[i % 8], size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('پێکهاتەی ${i + 1}', style: AppTextStyles.caption),
              const SizedBox(height: 8),
              GoldenButton(label: '${(i + 1) * 40} 💎', height: 34, fontSize: 11, onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
