import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// باکگراوندی گشتی بۆ هەموو شاشەکان — گرادیێنتی شاهانە + سیلوێتی قەڵای هەولێر
/// + کارتێکراوی ڕووناکی سەرەوە (spotlight).
class LuxuryBackground extends StatelessWidget {
  final Widget child;
  final bool showCitadel;

  const LuxuryBackground({
    super.key,
    required this.child,
    this.showCitadel = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.royalBackground),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.spotlight),
          ),
          if (showCitadel)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(double.infinity, 160),
                  painter: _CitadelSilhouettePainter(),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// وێنەیەکی سادەی سیلوێتی قەڵای هەولێر بە shape-based drawing
/// (بەبێ پێویستی بە فایلی وێنە).
class _CitadelSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.obsidian.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(0, size.height);
    final w = size.width;
    final h = size.height;

    path.lineTo(0, h * 0.55);
    double x = 0;
    const towerWidth = 46.0;
    int i = 0;
    while (x < w) {
      final towerHeight = (i.isEven ? 0.35 : 0.5) * h;
      path.lineTo(x, h - towerHeight);
      path.lineTo(x + towerWidth * 0.5, h - towerHeight - 14);
      path.lineTo(x + towerWidth, h - towerHeight);
      x += towerWidth;
      i++;
    }
    path.lineTo(w, h * 0.55);
    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
