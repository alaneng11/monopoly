import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// ئاگادارکردنەوەی لەناو ئەپ — نیشاندانی ئاگادارکردنەوەی پاڵی (توست)
/// بۆ: داواکاری هاوڕێ، دەستکەوتنەکان، کاتی بەندی ڕیز، ...
/// بانگدەکرێت لەرێگای [InAppNotificationOverlay.show(context, ...)]
class InAppNotification {
  final String title;
  final String? message;
  final IconData icon;
  final Color color;
  final Duration duration;

  const InAppNotification({
    required this.title,
    this.message,
    this.icon = Icons.notifications_active_rounded,
    this.color = AppColors.gold,
    this.duration = const Duration(seconds: 3),
  });
}

class InAppNotificationOverlay extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;

  const InAppNotificationOverlay({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  /// نیشاندانی ئاگادارکردنەوە لە هەر جێگایەک.
  static void show(BuildContext context, InAppNotification note) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _PositionedNotification(
        notification: note,
        onDismiss: () {
          entry?.remove();
          entry = null;
        },
      ),
    );
    overlay.insert(entry!);
  }

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PositionedNotification extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;
  const _PositionedNotification({required this.notification, required this.onDismiss});

  @override
  State<_PositionedNotification> createState() => _PositionedNotificationState();
}

class _PositionedNotificationState extends State<_PositionedNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _dismiss = Timer(widget.notification.duration, _hide);
  }

  void _hide() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.notification;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _hide,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.night2.withValues(alpha: 0.97),
                      note.color.withValues(alpha: 0.18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: note.color.withValues(alpha: 0.5), width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: note.color.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: note.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(note.icon, color: note.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            note.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.ivory,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (note.message != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              note.message!,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.parchment.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.close, color: AppColors.parchment.withValues(alpha: 0.4), size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
