import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

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
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(child: _podium()),
              const SizedBox(height: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: 10,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => FadeInUp(
                        delay: Duration(milliseconds: 40 * i),
                        child: _rankTile(i + 4),
                      ),
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

  Widget _podium() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final scale = compact ? 0.88 : 1.0;
        return SizedBox(
          height: compact ? 230 : 250,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _podiumSpot(rank: 2, name: 'ڕۆژان', score: '9.2K', height: 120 * scale, color: AppColors.sapphire),
                  _podiumSpot(rank: 1, name: 'هێمن', score: '14.8K', height: 150 * scale, color: AppColors.gold, crown: true),
                  _podiumSpot(rank: 3, name: 'کاوە', score: '7.6K', height: 96 * scale, color: AppColors.ruby),
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
          AvatarRing(size: crown ? 60 : 50, initials: name.substring(0, 1), level: rank),
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

  Widget _rankTile(int rank) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank', style: AppTextStyles.titleMedium.copyWith(color: AppColors.parchment.withValues(alpha: 0.6))),
          ),
          const AvatarRing(size: 42, initials: 'س', level: 5),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('یاریزانی $rank', style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
                Text('${5000 - rank * 120} خاڵ', style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: AppColors.success, size: 18),
        ],
      ),
    );
  }
}
