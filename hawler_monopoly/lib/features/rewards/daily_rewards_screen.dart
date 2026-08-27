import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/persistence.dart';
import '../../presentation/providers.dart';

/// شاشەی خەڵاتی ڕۆژانە — لۆژیکی ڕاستەقینەی پاشەکەوت و وەرگرتن.
class DailyRewardsScreen extends ConsumerStatefulWidget {
  const DailyRewardsScreen({super.key});

  @override
  ConsumerState<DailyRewardsScreen> createState() => _DailyRewardsScreenState();
}

class _DailyRewardsScreenState extends ConsumerState<DailyRewardsScreen> {
  static const _rewards = [100, 150, 200, 300, 400, 500, 1000];

  Map<String, dynamic> _daily = {'lastClaim': '', 'day': 0};
  bool _loading = true;
  bool _claimedToday = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await LocalPersistence.loadDailyReward();
    final today = _todayKey();
    final claimed = d['lastClaim'] == today;
    if (!mounted) return;
    setState(() {
      _daily = d;
      _claimedToday = claimed;
      _loading = false;
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _claim() async {
    if (_claimedToday) return;
    final today = _todayKey();
    final yesterday = _todayKeyOf(DateTime.now().subtract(const Duration(days: 1)));
    var day = (_daily['day'] as int? ?? 0);
    // ئەگەر دوێنێ نەبووبێت، زنجیرەکە دەستپێدەکرێتەوە
    day = _daily['lastClaim'] == yesterday ? (day % 7) + 1 : 1;
    final reward = _rewards[day - 1];

    await LocalPersistence.saveDailyReward({'lastClaim': today, 'day': day});
    await ref.read(profileProvider.notifier).addCoins(reward);
    await ref.read(achievementsProvider.notifier).unlock('first_claim');

    if (!mounted) return;
    setState(() {
      _daily = {'lastClaim': today, 'day': day};
      _claimedToday = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+$reward زێڕ وەرگیرا! 🎉')),
    );
  }

  String _todayKeyOf(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final currentDay = (_daily['day'] as int? ?? 0) + (_claimedToday ? 0 : 1);
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
                    Text('خەڵاتی ڕۆژانە', style: AppTextStyles.h2),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ResponsiveCenter(child: Column(
                      children: [
                        Text('٧ ڕۆژ بەردەوامبە بۆ وەرگرتنی خەڵاتی گەورە',
                            style: AppTextStyles.bodySoft, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth < 360 ? 2 : constraints.maxWidth < 560 ? 3 : 4;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 7,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.92,
                              ),
                              itemBuilder: (context, i) {
                                final day = i + 1;
                                final claimed = day < currentDay || (_claimedToday && day == currentDay);
                                final active = day == currentDay && !_claimedToday;
                                final isLast = day == 7;
                                return GlassContainer(
                                  borderRadius: 18,
                                  padding: const EdgeInsets.all(8),
                                  gradient: active ? AppColors.goldGradient : null,
                                  borderColor: active ? AppColors.goldBright : AppColors.glassBorder,
                                  shadows: active ? AppColors.goldGlow(blur: 16) : AppColors.softShadow(),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isLast ? Icons.card_giftcard : KurdishIcons.coin,
                                        size: isLast ? 26 : 20,
                                        color: active ? AppColors.night : (claimed ? AppColors.success : AppColors.gold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('${_rewards[i]}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: active ? AppColors.night : AppColors.parchment,
                                            fontWeight: FontWeight.w700,
                                          )),
                                      const SizedBox(height: 4),
                                      Text('ڕۆژی $day',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 10,
                                            color: active ? AppColors.night.withValues(alpha: 0.7) : AppColors.parchment.withValues(alpha: 0.5),
                                          )),
                                      if (claimed) const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                        GoldenButton(
                          label: _claimedToday ? 'ئەمڕۆ وەرگیراوە' : 'خەڵاتی ئەمڕۆ وەربگرە',
                          icon: _claimedToday ? Icons.check_circle : Icons.card_giftcard,
                          onTap: _claimedToday ? null : _claim,
                          variant: _claimedToday ? ButtonVariant.glass : ButtonVariant.gold,
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
}
