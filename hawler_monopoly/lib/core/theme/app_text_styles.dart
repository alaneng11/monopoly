import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// تایپۆگرافی — Noto Kufi Arabic باشترین پشتگیری بۆ کوردی سۆرانی دەکات
/// (تیپە بەستراوەکان و دیاکریتیکەکان بە ڕوونی پیشان دەدات).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color color = AppColors.ivory,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.notoKufiArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle display = _base(size: 40, weight: FontWeight.w800, height: 1.15);
  static TextStyle h1 = _base(size: 30, weight: FontWeight.w800, height: 1.2);
  static TextStyle h2 = _base(size: 24, weight: FontWeight.w700, height: 1.25);
  static TextStyle h3 = _base(size: 20, weight: FontWeight.w700, height: 1.3);
  static TextStyle titleMedium = _base(size: 17, weight: FontWeight.w600);
  static TextStyle body = _base(size: 15, weight: FontWeight.w500, color: AppColors.parchment);
  static TextStyle bodySoft = _base(
    size: 14,
    weight: FontWeight.w400,
    color: AppColors.parchment,
  );
  static TextStyle caption = _base(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.parchment.withValues(alpha: 0.7),
  );
  static TextStyle button = _base(
    size: 16,
    weight: FontWeight.w800,
    color: AppColors.night,
    letterSpacing: 0.2,
  );
  static TextStyle goldLabel = _base(
    size: 13,
    weight: FontWeight.w700,
    color: AppColors.gold,
  );
  static TextStyle tileLabel = _base(
    size: 9,
    weight: FontWeight.w700,
    color: AppColors.ivory,
    height: 1.1,
  );
  static TextStyle counter = _base(
    size: 22,
    weight: FontWeight.w800,
    color: AppColors.goldBright,
  );
}
