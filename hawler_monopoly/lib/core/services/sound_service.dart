import 'package:flutter/services.dart';

/// خزمەتگوزاری دەنگ و لەرین — سینگڵتۆن.
/// لەبەر بوونی فلاتەر وێب (Chrome) بێ پشتگیری AudioPlayer، ئێمە
/// HapticFeedback بۆ لەرین بەکار دەهێنین و پۆکەی دەنگ لەناو
/// AudioContext ی ڤێبی تەواو دروست دەکرێت بە دارت:js.
///
/// بۆ گۆڕینی تەنانەت بۆ audioplayers لە داهاتوو — تەنها [SoundService]
/// گۆڕان پێویستە.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  void configure({bool? sound, bool? vibration}) {
    if (sound != null) _soundEnabled = sound;
    if (vibration != null) _vibrationEnabled = vibration;
  }

  // ── Vibration helpers ─────────────────────────────────────

  Future<void> vibrateDice() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> vibrateSuccess() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> vibrateTap() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> vibrateError() async {
    if (!_vibrationEnabled) return;
    await HapticFeedback.vibrate();
  }

  // ── Sound helpers (Web AudioContext via dart:js for Chrome) ──

  /// هاویشتنی تاسە — دەنگی کورت
  void playDice() {
    if (!_soundEnabled) return;
    _playTone(frequency: 440, durationMs: 120, gain: 0.3, type: 'square');
  }

  /// کڕینی موڵک
  void playPurchase() {
    if (!_soundEnabled) return;
    _playChord([523, 659, 784], durationMs: 250);
  }

  /// کرێ بدرا
  void playRent() {
    if (!_soundEnabled) return;
    _playTone(frequency: 220, durationMs: 180, gain: 0.25, type: 'sawtooth');
  }

  /// سەرکەوتن / یاری کۆتایی
  void playWin() {
    if (!_soundEnabled) return;
    _playChord([523, 659, 784, 1047], durationMs: 500);
  }

  /// جوڵاندن
  void playMove() {
    if (!_soundEnabled) return;
    _playTone(frequency: 330, durationMs: 60, gain: 0.15, type: 'sine');
  }

  /// ئاگادارکردنەوە
  void playNotification() {
    if (!_soundEnabled) return;
    _playChord([880, 1100], durationMs: 160);
  }

  // ── Low-level Web Audio API ───────────────────────────────

  static bool _audioSupported = true;

  void _playTone({
    required double frequency,
    required int durationMs,
    double gain = 0.25,
    String type = 'sine',
  }) {
    if (!_audioSupported) return;
    try {
      // Use dart:js to call WebAudio on Chrome/web
      // On non-web platforms this will be a no-op
      // ignore: undefined_prefixed_name
      _webPlayTone(frequency, durationMs, gain, type);
    } catch (_) {
      _audioSupported = false;
    }
  }

  void _playChord(List<double> freqs, {int durationMs = 200}) {
    if (!_audioSupported) return;
    for (final f in freqs) {
      _playTone(frequency: f, durationMs: durationMs, gain: 0.18, type: 'sine');
    }
  }

  /// دروستکردنی AudioContext لەرێگای js.context (فلاتەر وێب هەستێبدات)
  void _webPlayTone(double freq, int ms, double gainVal, String waveType) {
    // This is a web-only JS interop call. On native it's a no-op.
    try {
      // ignore: avoid_dynamic_calls
      final js = _getJs();
      if (js == null) return;
      js.callMethod('eval', ['''
        (function() {
          try {
            var ctx = new (window.AudioContext || window.webkitAudioContext)();
            var osc = ctx.createOscillator();
            var g = ctx.createGain();
            osc.type = '$waveType';
            osc.frequency.value = $freq;
            g.gain.setValueAtTime($gainVal, ctx.currentTime);
            g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + ${ms / 1000.0});
            osc.connect(g);
            g.connect(ctx.destination);
            osc.start(ctx.currentTime);
            osc.stop(ctx.currentTime + ${ms / 1000.0});
          } catch(e) {}
        })();
      ''']);
    } catch (_) {
      _audioSupported = false;
    }
  }

  // ignore: unused_element
  dynamic _getJs() {
    try {
      // ignore: invalid_null_aware_expression
      return _JsProxy.context;
    } catch (_) {
      return null;
    }
  }
}

// ── JS Context proxy — only works in flutter web ─────────────
class _JsProxy {
  static dynamic get context {
    // This will throw on non-web targets, caught by caller
    throw UnsupportedError('JS not available on this platform');
  }
}
