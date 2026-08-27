import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

/// پرۆفایل — داتای ڕاستەقینەی یاریزان و ئامارەکان.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
            maxLength: 16,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'ناوی نوێ',
              hintStyle: AppTextStyles.bodySoft,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('پاشگەزبوونەوە', style: AppTextStyles.goldLabel),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(profileProvider.notifier).setName(editController.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('پاشەکەوت', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
            ),
          ],
        ),
      );
    }

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
                  child: ResponsiveCenter(child: Column(
                    children: [
                      FadeInDown(
                        child: AvatarRing(
                          size: 100,
                          initials: profile.name.isNotEmpty ? profile.name.substring(0, 1) : '؟',
                          level: profile.level,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(profile.name, style: AppTextStyles.h2),
                      Text('@${profile.username}', style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      const GoldDivider(),
                      const SizedBox(height: 20),
                      _statsRow(profile),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'ئاستی پێشکەوتن'),
                      const SizedBox(height: 10),
                      _levelCard(profile),
                    ],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
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
