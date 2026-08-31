import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

import '../../data/online/online_repository.dart';
import '../../presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _tab = 0;
  final tabs = const ['دراو', 'بەرد', 'چوارچێوە', 'ڕووکار'];
  List<CosmeticItem> _catalog = [];
  List<CosmeticItem> _inventory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    try {
      final items = await ShopRepository.instance.getCatalog();
      final inv = await ShopRepository.instance.getInventory();
      if (mounted) {
        setState(() {
          _catalog = items;
          _inventory = inv;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buyOrEquip(CosmeticItem item) async {
    final isOwned = _inventory.any((i) => i.id == item.id);
    if (isOwned) {
      final ok = await ShopRepository.instance.equipItem(item.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} بەکارخرا! ✨')));
        _loadShopData();
      }
    } else {
      final currency = item.gemPrice > 0 ? 'gems' : 'coins';
      final ok = await ShopRepository.instance.buyItem(item.id, currency: currency);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} بە سەرکەوتوویی کڕدرا! 🎉')));
        _loadShopData();
        ref.read(profileProvider.notifier).refresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دراوی پێویستت نییە بۆ کڕین!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final coins = profile?.coins ?? 0;
    final gems = profile?.gems ?? 0;

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
                    Text('بازاڕی هەولێر', style: AppTextStyles.h2),
                    const Spacer(),
                    CurrencyPill(icon: KurdishIcons.coin, value: '$coins', color: AppColors.gold),
                    const SizedBox(width: 8),
                    CurrencyPill(icon: KurdishIcons.gem, value: '$gems', color: AppColors.sapphire),
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
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : SingleChildScrollView(
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
      (1000, '٩٩٩ د.ع', false),
      (5500, '٤٬٩٩٩ د.ع', true),
      (12000, '٩٬٩٩٩ د.ع', false),
      (30000, '١٩٬٩٩٩ د.ع', false),
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
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(KurdishIcons.coin, color: AppColors.night, size: 24),
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
                Text('پاکێجی زێڕی هەولێر', style: AppTextStyles.caption),
              ],
            ),
          ),
          GoldenButton(label: priceLabel, height: 40, fontSize: 12, onTap: () {}),
        ],
      ),
    );
  }

  Widget _itemGrid() {
    final cat = _tab == 1 ? 'dice' : (_tab == 2 ? 'frame' : 'theme');
    final items = _catalog.where((i) => i.category == cat).toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('هیچ کاڵایەک بەردەست نییە لەم بەشەدا.', style: AppTextStyles.bodySoft),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        final isOwned = _inventory.any((inv) => inv.id == item.id);
        final isEquipped = _inventory.any((inv) => inv.id == item.id && inv.isEquipped);

        return FadeInUp(
          delay: Duration(milliseconds: 50 * i),
          child: GlassContainer(
            borderRadius: 20,
            padding: const EdgeInsets.all(14),
            borderColor: isEquipped ? AppColors.gold : AppColors.glassBorder,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(item.icon, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(item.name, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                GoldenButton(
                  label: isEquipped ? 'بەکارخراوە ✓' : (isOwned ? 'بەکارخستن' : (item.gemPrice > 0 ? '${item.gemPrice} 💎' : '${item.coinPrice} 🪙')),
                  height: 34,
                  fontSize: 11,
                  onTap: isEquipped ? null : () => _buyOrEquip(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
