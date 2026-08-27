import 'package:flutter/material.dart';

/// یارمەتیدەری وەڵامدانەوە (Responsive) — لەسەر مۆبایل هیچ کاریگەری نییە،
/// بەڵام لەسەر تابلێت/فۆڵد/دیسکتۆپ ناوەڕۆک لە ناوەڕاست ڕادەگرێت و
/// ڕێگری دەکات لە کێشانی زۆر فراوانی کارتەکان.
///
/// بەکارهێنان: تەنها SingleChildScrollView یان body-ی سەرەکی بپێچەرەوە.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 560,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// بەرین (breakpoints) بۆ گۆڕینی ژمارەی ستوونەکان لە grid-ەکان.
class Breakpoints {
  Breakpoints._();
  static const double compact = 600; // مۆبایل
  static const double medium = 1024; // تابلێت
  // > medium => desktop/large tablet

  static bool isCompact(BuildContext c) => MediaQuery.of(c).size.width < compact;
  static bool isMedium(BuildContext c) =>
      MediaQuery.of(c).size.width >= compact && MediaQuery.of(c).size.width < medium;
  static bool isExpanded(BuildContext c) => MediaQuery.of(c).size.width >= medium;

  /// ژمارەی ستوونی گونجاو بۆ grid-ی کارتی بازاڕ/کۆگا/ئەفتخارات.
  static int gridColumns(BuildContext c, {int compactCols = 2, int mediumCols = 3, int expandedCols = 4}) {
    if (isExpanded(c)) return expandedCols;
    if (isMedium(c)) return mediumCols;
    return compactCols;
  }
}
