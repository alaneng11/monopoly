import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      context.go('/login');
    });
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
