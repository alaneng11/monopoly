import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/api_client.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _period = 'weekly'; // weekly, monthly, all_time
  List<Map<String, dynamic>> _leaders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _loading = true);
    final res = await ApiClient.instance.getLeaderboard(_period);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      final list = (res.data!['leaders'] ?? res.data!['leaderboard']) as List?;
      setState(() {
        _leaders = list?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _switchPeriod(String p) {
    if (_period == p) return;
    setState(() => _period = p);
    _fetchLeaderboard();
  }

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
                    Text('پلەبەندی شکۆداران', style: AppTextStyles.h2),
                    const Spacer(),
                    CircleIconButton(icon: Icons.refresh, onTap: _fetchLeaderboard),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Period Switcher
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _tabButton('weekly', 'هەفتانە'),
                      _tabButton('monthly', 'مانگانە'),
                      _tabButton('all_time', 'گشتی'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : _leaders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events_outlined, color: AppColors.gold.withValues(alpha: 0.4), size: 48),
                                const SizedBox(height: 12),
                                Text('هیچ داتایەک نەدۆزرایەوە', style: AppTextStyles.bodySoft),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              if (_leaders.length >= 3)
                                FadeInDown(child: _podium())
                              else
                                const SizedBox(height: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 560),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                      itemCount: _leaders.length > 3 ? _leaders.length - 3 : _leaders.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, i) {
                                        final actualIdx = _leaders.length >= 3 ? i + 3 : i;
                                        return FadeInUp(
                                          delay: Duration(milliseconds: 30 * i),
                                          child: _rankTile(actualIdx + 1, _leaders[actualIdx]),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String key, String title) {
    final active = _period == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchPeriod(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? AppColors.goldGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: active ? AppColors.night : AppColors.parchment,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _podium() {
    final p1 = _leaders[0];
    final p2 = _leaders[1];
    final p3 = _leaders[2];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final scale = compact ? 0.88 : 1.0;
        return SizedBox(
          height: compact ? 220 : 240,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _podiumSpot(
                    rank: 2,
                    name: (p2['displayName'] ?? p2['display_name'] ?? p2['name']) as String? ?? 'یاریزان ٢',
                    score: '${p2['wins'] ?? p2['score'] ?? 0} بردنەوە',
                    height: 120 * scale,
                    color: AppColors.sapphire,
                  ),
                  _podiumSpot(
                    rank: 1,
                    name: (p1['displayName'] ?? p1['display_name'] ?? p1['name']) as String? ?? 'یاریزان ١',
                    score: '${p1['wins'] ?? p1['score'] ?? 0} بردنەوە',
                    height: 150 * scale,
                    color: AppColors.gold,
                    crown: true,
                  ),
                  _podiumSpot(
                    rank: 3,
                    name: (p3['displayName'] ?? p3['display_name'] ?? p3['name']) as String? ?? 'یاریزان ٣',
                    score: '${p3['wins'] ?? p3['score'] ?? 0} بردنەوە',
                    height: 96 * scale,
                    color: AppColors.ruby,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _podiumSpot({
    required int rank,
    required String name,
    required String score,
    required double height,
    required Color color,
    bool crown = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (crown) const Icon(KurdishIcons.crown, color: AppColors.goldBright, size: 22),
          AvatarRing(size: crown ? 58 : 48, initials: name.isNotEmpty ? name.substring(0, 1) : '؟', level: rank),
          const SizedBox(height: 4),
          Text(name, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          Text(score, style: AppTextStyles.goldLabel.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Container(
            width: 76,
            height: height * 0.44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color.withValues(alpha: 0.6)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text('$rank', style: AppTextStyles.h2.copyWith(color: color, fontSize: 22)),
          ),
        ],
      ),
    );
  }

  Widget _rankTile(int rank, Map<String, dynamic> item) {
    final name = (item['displayName'] ?? item['display_name'] ?? item['name']) as String? ?? 'یاریزان';
    final wins = item['wins'] ?? item['score'] ?? 0;
    final level = item['level'] ?? 1;

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank', style: AppTextStyles.titleMedium.copyWith(color: AppColors.parchment.withValues(alpha: 0.6))),
          ),
          AvatarRing(size: 40, initials: name.isNotEmpty ? name.substring(0, 1) : '؟', level: (level as num).toInt()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                Text('$wins بردنەوە  •  ئاست $level', style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}
