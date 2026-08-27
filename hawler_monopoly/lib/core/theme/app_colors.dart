import 'package:flutter/material.dart';

/// پاڵێتی ڕەنگی "هەولێر مۆنۆپۆلی" — ئیلهام وەرگیراوە لە دیوارە قوڕینەکانی
/// قەڵای هەولێر، زێڕی بازاڕی قەیسەری و ئاسمانی زەردی ئێواران.
class AppColors {
  AppColors._();

  // ---- Core brand ----
  static const Color citadelBrown = Color(0xFF3E2418); // قوڕی قەڵا
  static const Color citadelBrownDark = Color(0xFF2A160D);
  static const Color terracotta = Color(0xFFB5602E); // خشتی سوور
  static const Color sand = Color(0xFFE8C99B); // خۆڵی زەرد
  static const Color sandLight = Color(0xFFF3E3C3);

  static const Color gold = Color(0xFFE8B94A);
  static const Color goldBright = Color(0xFFFFE08A);
  static const Color goldDeep = Color(0xFFB4842A);

  static const Color emerald = Color(0xFF1E7A5F); // کەشکۆڵی سەوز
  static const Color sapphire = Color(0xFF1F5C8B); // شینی کانی
  static const Color ruby = Color(0xFFA8283F);
  static const Color amethyst = Color(0xFF6C4A93);

  static const Color night = Color(0xFF120B08); // شەوی هەولێر
  static const Color night2 = Color(0xFF1C120C);
  static const Color obsidian = Color(0xFF0D0906);

  static const Color ivory = Color(0xFFFBF3E4);
  static const Color parchment = Color(0xFFF1E3C4);

  static const Color success = Color(0xFF2FBF71);
  static const Color danger = Color(0xFFE0435A);
  static const Color info = Color(0xFF4AA3E8);

  // ---- Gradients ----
  static const LinearGradient royalBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [night, citadelBrownDark, night2],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldBright, gold, goldDeep],
  );

  static const LinearGradient goldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold],
  );

  static const LinearGradient citadelCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A2E1E), Color(0xFF2E1B11)],
  );

  static const LinearGradient emeraldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF35A57E), emerald],
  );

  static const LinearGradient duskSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2C1B4A), Color(0xFFB5602E), Color(0xFFE8B94A)],
  );

  static const RadialGradient spotlight = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [Color(0x33E8B94A), Color(0x00000000)],
  );

  // ---- Glass ----
  static Color glassFill = Colors.white.withValues(alpha: 0.08);
  static Color glassBorder = Colors.white.withValues(alpha: 0.18);
  static Color glassFillStrong = Colors.white.withValues(alpha: 0.14);

  // ---- Board tile colors (property groups) ----
  static const List<Color> propertyGroups = [
    Color(0xFF8B4A2B), // قاوەیی
    Color(0xFF4AA3E8), // شین
    Color(0xFFD44D6E), // پەمەیی
    Color(0xFFE8A23A), // پرتەقاڵی
    Color(0xFFE0435A), // سوور
    Color(0xFFEFD24A), // زەرد
    Color(0xFF2FBF71), // سەوز
    Color(0xFF1F5C8B), // شینی تۆخ
  ];

  static List<BoxShadow> softShadow({Color? color, double blur = 24}) => [
        BoxShadow(
          color: (color ?? Colors.black).withValues(alpha: 0.35),
          blurRadius: blur,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> goldGlow({double blur = 30}) => [
        BoxShadow(
          color: gold.withValues(alpha: 0.45),
          blurRadius: blur,
          spreadRadius: -4,
        ),
      ];
}
