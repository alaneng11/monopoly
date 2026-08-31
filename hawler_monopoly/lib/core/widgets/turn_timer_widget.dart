import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// ئامانجی دووری — نیشانەی شمارەی پاشڕۆنی ٣٠ چرکە بۆ هەر ڕیزێک.
/// نیشانەی سوور لە ژێر ١٠ چرکە.
/// [turnStartedAt] — timestamp (Unix seconds) کاتی دەستپێکردنی ڕیزی ئێستا.
/// [onTimeout] — پاش مامەڵە کاتی خۆیەتی بانگدەکرێت.
class TurnTimerWidget extends StatefulWidget {
  final int? turnStartedAt; // Unix epoch seconds from server
  final int totalSeconds;
  final VoidCallback? onTimeout;

  const TurnTimerWidget({
    super.key,
    this.turnStartedAt,
    this.totalSeconds = 30,
    this.onTimeout,
  });

  @override
  State<TurnTimerWidget> createState() => _TurnTimerWidgetState();
}

class _TurnTimerWidgetState extends State<TurnTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _arc;
  Timer? _tick;
  int _remaining = 30;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _arc = AnimationController(vsync: this, duration: Duration(seconds: widget.totalSeconds));
    _init();
  }

  void _init() {
    _tick?.cancel();
    _timedOut = false;
    final started = widget.turnStartedAt;
    if (started == null) {
      _remaining = widget.totalSeconds;
      _arc.value = 1.0;
      return;
    }

    final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - started;
    _remaining = (widget.totalSeconds - elapsed).clamp(0, widget.totalSeconds);

    if (_remaining <= 0) {
      _arc.value = 0.0;
      return;
    }

    _arc.value = _remaining / widget.totalSeconds;
    _arc.animateTo(0, duration: Duration(seconds: _remaining), curve: Curves.linear);

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, widget.totalSeconds));
      if (_remaining <= 0 && !_timedOut) {
        _timedOut = true;
        widget.onTimeout?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TurnTimerWidget old) {
    super.didUpdateWidget(old);
    if (old.turnStartedAt != widget.turnStartedAt) {
      _init();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _arc.dispose();
    super.dispose();
  }

  Color get _color {
    if (_remaining <= 5) return AppColors.danger;
    if (_remaining <= 10) return AppColors.gold;
    return AppColors.emerald;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.turnStartedAt == null) return const SizedBox.shrink();

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _arc,
            builder: (_, __) => CustomPaint(
              painter: _ArcPainter(progress: _arc.value, color: _color),
              size: const Size(36, 36),
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: AppTextStyles.caption.copyWith(
              color: _color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
            child: Text('$_remaining'),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final Color color;
  _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 2;
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), r, bg);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color;
}
