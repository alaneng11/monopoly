import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/providers.dart';

/// ڕێکخستنەکان — پاشەکەوتی ڕاستەقینە لە SharedPreferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings == null) {
      return const Scaffold(
        body: LuxuryBackground(child: Center(child: CircularProgressIndicator(color: AppColors.gold))),
      );
    }
    final controller = ref.read(settingsProvider.notifier);

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
                    Text('ڕێکخستنەکان', style: AppTextStyles.h2),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveCenter(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'دەنگ و ئاگادارکردنەوە'),
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            _switchTile('دەنگی یاری', Icons.volume_up, settings.sound, (v) => controller.set('sound', v)),
                            _divider(),
                            _switchTile('میوزیک', Icons.music_note, settings.music, (v) => controller.set('music', v)),
                            _divider(),
                            _switchTile('ئاگادارکردنەوە', Icons.notifications, settings.notifications,
                                (v) => controller.set('notifications', v)),
                            _divider(),
                            _switchTile('لەرین', Icons.vibration, settings.vibration, (v) => controller.set('vibration', v)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'هەژمار'),
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            _navTile('گۆڕینی زمان', Icons.language, 'کوردی'),
                            _divider(),
                            _navTile('یارمەتی', Icons.help_outline, null),
                            _divider(),
                            _navTile('دەربارە', Icons.info_outline, 'v2.0.0'),
                          ],
                        ),
                      ),
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

  Widget _divider() => Divider(color: AppColors.glassBorder, height: 1);

  Widget _switchTile(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold, size: 20),
      title: Text(label, style: AppTextStyles.body),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.night,
        activeTrackColor: AppColors.gold,
        inactiveThumbColor: AppColors.parchment,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _navTile(String label, IconData icon, String? value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold, size: 20),
      title: Text(label, style: AppTextStyles.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value, style: AppTextStyles.caption),
          const SizedBox(width: 4),
          Icon(Icons.chevron_left, color: AppColors.parchment.withValues(alpha: 0.5), size: 18),
        ],
      ),
      onTap: () {},
    );
  }
}
