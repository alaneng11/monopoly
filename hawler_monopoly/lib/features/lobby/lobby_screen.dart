import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../presentation/game_session_controller.dart';
import 'local_setup_screen.dart';
import 'online_lobby_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _hasSavedGame = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final session = ref.read(gameSessionProvider);
    final has = session.hasGame;
    if (!mounted) return;
    setState(() {
      _hasSavedGame = has;
      _checking = false;
    });
  }

  Future<void> _resume() async {
    await ref.read(gameSessionProvider.notifier).tryResumeSavedGame();
    if (!mounted) return;
    if (ref.read(gameSessionProvider).hasGame) {
      context.push('/game');
    }
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
                    CircleIconButton(icon: Icons.arrow_forward, onTap: () => context.pop()),
                    const SizedBox(width: 12),
                    Text('هۆڵی یاری', style: AppTextStyles.h2),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_checking && _hasSavedGame) ...[
                          FadeInUp(
                            child: GlassContainer(
                              borderRadius: 22,
                              padding: const EdgeInsets.all(18),
                              borderColor: AppColors.gold.withValues(alpha: 0.5),
                              child: Row(
                                children: [
                                  const Icon(Icons.save_rounded, color: AppColors.goldBright, size: 30),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('یاری پاشەکەوتکراو', style: AppTextStyles.titleMedium),
                                        const SizedBox(height: 4),
                                        Text('بەردەوامبە لە شوێنی خۆت', style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                  GoldenButton(
                                    label: 'بەردەوامبوون',
                                    height: 42,
                                    fontSize: 13,
                                    onTap: _resume,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Online Multiplayer Mode Card
                        FadeInUp(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnlineLobbyScreen())),
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: AppColors.goldGradient,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: AppColors.goldGlow(blur: 26),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  const Icon(Icons.cloud_circle_rounded, size: 46, color: AppColors.night),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('یاریی ئۆنلاین', style: AppTextStyles.h2.copyWith(color: AppColors.night)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ژووری خۆت دروستبکە یان بە کۆد بەشداربە لەگەڵ هاوڕێکانت',
                                          style: AppTextStyles.caption.copyWith(color: AppColors.night.withValues(alpha: 0.85), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left, color: AppColors.night),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Local Setup Mode Card
                        FadeInUp(
                          delay: const Duration(milliseconds: 100),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalSetupScreen())),
                            child: GlassContainer(
                              borderRadius: 26,
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.sapphire.withValues(alpha: 0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.phonelink, size: 26, color: AppColors.gold),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('یاریی ناوخۆیی (Pass & Play)', style: AppTextStyles.h3),
                                        const SizedBox(height: 4),
                                        Text(
                                          '٢–٦ یاریزان لەسەر یەک مۆبایل',
                                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_left, color: AppColors.parchment),
                                ],
                              ),
                            ),
                          ),
                        ),
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
}
