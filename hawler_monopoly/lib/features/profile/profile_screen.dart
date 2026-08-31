import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

/// پرۆفایل — داتای ڕاستەقینەی یاریزان لە سێرڤەر و ئامارەکان.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _presetAvatars = ['👑', '🦁', '🦅', '⚔️', '🏰', '💰', '🎲', '🎩', '🌟', '💎'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    if (profile == null) {
      return const Scaffold(
        body: LuxuryBackground(child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
      );
    }

    final editController = TextEditingController(text: profile.name);

    void editName() {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.night2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('گۆڕینی ناو', style: AppTextStyles.h3),
          content: TextField(
            controller: editController,
            style: AppTextStyles.body,
            maxLength: 20,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ناوی نوێ',
              hintStyle: AppTextStyles.bodySoft,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('پاشگەزبوونەوە', style: AppTextStyles.caption),
            ),
            TextButton(
              onPressed: () async {
                final newName = editController.text.trim();
                if (newName.isNotEmpty) {
                  await ref.read(profileProvider.notifier).setName(newName);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('پاشەکەوت', style: AppTextStyles.goldLabel),
            ),
          ],
        ),
      );
    }

    void chooseAvatar() {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.royalBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('هەڵبژاردنی وێنەی پرۆفایل', style: AppTextStyles.h3),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetAvatars.map((emoji) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(profileProvider.notifier).setAvatar(emoji);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    final avatarDisplay = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
        ? profile.avatarUrl!
        : (profile.name.isNotEmpty ? profile.name.substring(0, 1) : '؟');

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
                    const Spacer(),
                    Text('پرۆفایل', style: AppTextStyles.h2),
                    const Spacer(),
                    CircleIconButton(icon: Icons.edit, onTap: editName),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveCenter(
                    child: Column(
                      children: [
                        FadeInDown(
                          child: GestureDetector(
                            onTap: chooseAvatar,
                            child: Stack(
                              children: [
                                AvatarRing(
                                  size: 96,
                                  initials: avatarDisplay,
                                  level: profile.level,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.goldGradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.night, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: AppColors.night),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(profile.name, style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        if (profile.id.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: profile.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('ناسنامەی (ID) کۆپیکرا')),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ID: ${profile.id.substring(0, profile.id.length > 12 ? 12 : profile.id.length)}...',
                                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.goldBright),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.copy, size: 13, color: AppColors.goldBright),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text('@${profile.username}', style: AppTextStyles.caption),
                        const SizedBox(height: 12),
                        const GoldDivider(),
                        const SizedBox(height: 18),
                        _currencyRow(profile),
                        const SizedBox(height: 16),
                        _statsRow(profile),
                        const SizedBox(height: 24),
                        const SectionHeader(title: 'ئاستی پێشکەوتن'),
                        const SizedBox(height: 10),
                        _levelCard(profile),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currencyRow(ProfileState profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CurrencyPill(icon: KurdishIcons.coin, value: '${profile.coins} زێڕ'),
        const SizedBox(width: 14),
        CurrencyPill(icon: KurdishIcons.gem, value: '${profile.gems} یاقووت', color: AppColors.sapphire),
        const SizedBox(width: 14),
        CurrencyPill(icon: Icons.local_fire_department, value: '${profile.streak} ڕۆژ', color: AppColors.ruby),
      ],
    );
  }

  Widget _statsRow(ProfileState profile) {
    final stats = [
      ('${profile.games}', 'یاری', Icons.videogame_asset),
      ('${profile.wins}', 'بردنەوە', Icons.emoji_events),
      ('${(profile.winRate * 100).round()}%', 'ڕێژەی بردنەوە', Icons.percent),
    ];
    return Row(
      children: List.generate(stats.length, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: i < stats.length - 1 ? 10 : 0),
          child: GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(stats[i].$3, color: AppColors.gold, size: 20),
                const SizedBox(height: 6),
                Text(stats[i].$1, style: AppTextStyles.titleMedium),
                Text(stats[i].$2, style: AppTextStyles.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _levelCard(ProfileState profile) {
    final progress = (profile.xpInLevel / 1000).clamp(0.0, 1.0);
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Text('ئاست ${profile.level}', style: AppTextStyles.titleMedium),
              const Spacer(),
              Text('${profile.xpInLevel} / 1000 XP', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}
