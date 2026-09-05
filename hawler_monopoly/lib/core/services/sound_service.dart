import 'package:flutter/services.dart';

import 'audio_stub.dart' if (dart.library.js_interop) 'audio_web.dart' as audio;

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
  //
  // ئیمپلیمێنتەیشنەکە لە `audio_web.dart` (وێب) یان `audio_stub.dart`
  // (پلاتفۆرمەکانی تر) دێت بە ڕێگەی conditional import.

  bool get isAudioSupported => audio.audioSupported;

  /// دەبێت دوای یەکەم کرتەی بەکارهێنەر بانگ بکرێت — وێبگەڕەکان
  /// AudioContext ڕادەگرن تا ئەو کاتە.
  void unlockAudio() {
    if (!_soundEnabled) return;
    audio.resumeAudio();
  }

  void _playTone({
    required double frequency,
    required int durationMs,
    double gain = 0.25,
    String type = 'sine',
  }) {
    audio.playTone(
      frequency: frequency,
      durationMs: durationMs,
      gain: gain,
      type: type,
    );
  }

  void _playChord(List<double> freqs, {int durationMs = 200}) {
    for (final f in freqs) {
      _playTone(frequency: f, durationMs: durationMs, gain: 0.18, type: 'sine');
    }
  }
}
