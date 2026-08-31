import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/api_client.dart';
import '../../data/online/chat_repository.dart';
import '../../presentation/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final startTime = DateTime.now();
    final hasSession = await ApiClient.instance.restoreSession();

    if (hasSession) {
      final me = await ApiClient.instance.getProfile();
      if (me.ok && me.data != null) {
        final user = me.data!['user'] as Map<String, dynamic>?;
        if (user != null) {
          await ref.read(profileProvider.notifier).syncWithServer(user);
        }
      }
      ChatRepository.instance.init();
    }

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 1800) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    if (hasSession) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxuryBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZoomIn(
                duration: const Duration(milliseconds: 900),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: AppColors.goldGlow(blur: 40),
                    border: Border.all(color: AppColors.ivory.withValues(alpha: 0.5), width: 3),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 62,
                    color: AppColors.night,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  'مۆنۆپۆلی هەولێر',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.goldBright,
                    shadows: [
                      Shadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInUp(
                delay: const Duration(milliseconds: 700),
                child: Text(
                  'شاری زێڕین، یاریی شکۆدار',
                  style: AppTextStyles.bodySoft.copyWith(letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 56),
              FadeIn(
                delay: const Duration(milliseconds: 1000),
                child: SizedBox(
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      color: AppColors.gold,
                      backgroundColor: Color(0x22FFFFFF),
                      minHeight: 4,
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
