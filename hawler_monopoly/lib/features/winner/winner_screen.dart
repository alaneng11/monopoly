import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models/game_models.dart';
import '../../presentation/game_session_controller.dart';

/// شاشەی ئەنجامی یاری — ڕیزبەندی تەواوی یاریزانەکان بەپێی سامان.
class WinnerScreen extends ConsumerStatefulWidget {
  final String winnerName;
  final Color winnerColor;
  final List<Player> players;
  final Map<String, int> netWorths;
  final int round;

  const WinnerScreen({
    super.key,
    required this.winnerName,
    required this.winnerColor,
    required this.players,
    required this.netWorths,
    required this.round,
  });

  @override
  ConsumerState<WinnerScreen> createState() => _WinnerScreenState();
}

class _WinnerScreenState extends ConsumerState<WinnerScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 4))..play();

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = [...widget.players]..sort((a, b) => (widget.netWorths[b.id] ?? 0).compareTo(widget.netWorths[a.id] ?? 0));
    final winner = ranked.firstWhere((p) => p.name == widget.winnerName, orElse: () => ranked.first);
    final totalWorth = widget.netWorths[winner.id] ?? 0;

    return Scaffold(
      body: LuxuryBackground(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: pi / 2,
                emissionFrequency: 0.06,
                numberOfParticles: 18,
                maxBlastForce: 20,
                minBlastForce: 8,
                gravity: 0.25,
                colors: const [AppColors.gold, AppColors.goldBright, AppColors.emerald, AppColors.sapphire],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ZoomIn(
                      duration: const Duration(milliseconds: 700),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.goldGradient,
                          boxShadow: AppColors.goldGlow(blur: 50),
                        ),
                        child: CircleAvatar(
                          radius: 58,
                          backgroundColor: winner.color,
                          child: Icon(winner.character.icon, size: 52, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      child: Text('${widget.winnerName} سەرکەوتوو بوو!',
                          style: AppTextStyles.h1.copyWith(color: AppColors.goldBright), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 6),
                    FadeInUp(
                      delay: const Duration(milliseconds: 120),
                      child: Text('تۆ بوویت بە خاوەنی شاری هەولێر', style: AppTextStyles.body, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 26),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: GlassContainer(
                        borderRadius: 22,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('${winner.propertiesOwned}', 'موڵک', Icons.location_city),
                            _vDivider(),
                            _stat(_format(totalWorth), 'کۆی سامان', KurdishIcons.coin),
                            _vDivider(),
                            _stat('${widget.round}', 'دۆرە', Icons.replay_circle_filled),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInUp(
                      delay: const Duration(milliseconds: 280),
                      child: GlassContainer(
                        borderRadius: 22,
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ڕیزبەندی کۆتایی', style: AppTextStyles.titleMedium),
                            const SizedBox(height: 12),
                            ...ranked.asMap().entries.map((e) {
                              final p = e.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Text(
                                      e.key == 0 ? '🥇' : e.key == 1 ? '🥈' : e.key == 2 ? '🥉' : '${e.key + 1}',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${p.name}${p.bankrupt ? ' — پەرەو' : ''}',
                                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                    ),
                                    Text('${_format(widget.netWorths[p.id] ?? 0)} 💰', style: AppTextStyles.caption.copyWith(color: AppColors.goldBright)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeInUp(
                      delay: const Duration(milliseconds: 340),
                      child: GoldenButton(
                        label: 'ماڵەوە',
                        icon: Icons.home_rounded,
                        height: 54,
                        width: double.infinity,
                        variant: ButtonVariant.glass,
                        onTap: () {
                          ref.read(gameSessionProvider.notifier).quitGame();
                          context.go('/home');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(int v) => v >= 10000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';

  Widget _stat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.titleMedium),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 40, color: AppColors.glassBorder);
}
