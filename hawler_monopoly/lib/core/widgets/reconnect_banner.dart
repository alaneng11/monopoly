import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// بەندی ئاگادارکردنەوەی دووبارەپەیوەندبوون — دەرکەوتە لەسەر بۆردی یاری کاتێک WebSocket قەتبووە.
/// بە خۆماتیکی دەشارێتەوە کاتێک پەیوەندی دووبارە دروست بێت.
class ReconnectBanner extends StatefulWidget {
  const ReconnectBanner({super.key});

  @override
  State<ReconnectBanner> createState() => _ReconnectBannerState();
}

class _ReconnectBannerState extends State<ReconnectBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.72 + _pulse.value * 0.18),
              AppColors.danger.withValues(alpha: 0.50 + _pulse.value * 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.35 * _pulse.value),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'پەیوەندی دەگەڕێتەوە...',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'یارییەکە پاشەکەوت دەکرێت — چاوەڕوان بە',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نیشانەی پەیوەندی — خاڵی بچووکی سووری/سەوزی لە هێمای گۆشەی هێمای یاری.
class ConnectionDot extends StatelessWidget {
  final bool connected;
  const ConnectionDot({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? AppColors.success : AppColors.danger,
        boxShadow: [
          BoxShadow(
            color: (connected ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.5),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
