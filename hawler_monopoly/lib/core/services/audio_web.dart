import 'dart:js_interop';

/// دەنگی سینتێسایزکراو بۆ فلاتەر وێب بە Web Audio API.
///
/// پێشتر ئەم بەشە بە `dart:js` ی کۆن نووسرابوو و هەمیشە `UnsupportedError`ی
/// هەڵدەدا — واتە هیچ دەنگێک لێ نەدەدرا. ئێستا بە `dart:js_interop`ی
/// فەرمییە و یەک `AudioContext`ی هاوبەش بەکاردەهێنێت (وێبگەڕەکان ژمارەی
/// AudioContextـەکان سنووردار دەکەن، بۆیە دروستکردنی یەکێک بۆ هەر دەنگێک
/// دوای چەند جارێک بێدەنگ شکست دەهێنا).

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external _AudioContext();
  external _Oscillator createOscillator();
  external _GainNode createGain();
  external JSObject get destination;
  external double get currentTime;
  external String get state;
  external void resume();
}

extension type _Oscillator._(JSObject _) implements JSObject {
  external set type(String v);
  external _AudioParam get frequency;
  external void connect(JSObject target);
  external void start(double when);
  external void stop(double when);
}

extension type _GainNode._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external void connect(JSObject target);
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double v);
  external void setValueAtTime(double value, double startTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
}

_AudioContext? _ctx;
bool _unavailable = false;

_AudioContext? _context() {
  if (_unavailable) return null;
  if (_ctx != null) return _ctx;
  try {
    // ئەگەر وێبگەڕەکە پشتگیری نەکات، constructorـەکە هەڵە هەڵدەدات و
    // catchـەکەی خوارەوە بۆ هەمیشە ناچالاکی دەکات.
    _ctx = _AudioContext();
    return _ctx;
  } catch (_) {
    _unavailable = true;
    return null;
  }
}

bool get audioSupported => !_unavailable;

/// وێبگەڕەکان AudioContext ڕادەگرن تا ئەو کاتەی بەکارهێنەر کرتەیەک دەکات.
void resumeAudio() {
  try {
    final ctx = _context();
    if (ctx != null && ctx.state == 'suspended') ctx.resume();
  } catch (_) {}
}

void playTone({
  required double frequency,
  required int durationMs,
  required double gain,
  required String type,
}) {
  try {
    final ctx = _context();
    if (ctx == null) return;
    if (ctx.state == 'suspended') ctx.resume();

    final osc = ctx.createOscillator();
    final g = ctx.createGain();
    final t0 = ctx.currentTime;
    final t1 = t0 + durationMs / 1000.0;

    osc.type = type;
    osc.frequency.value = frequency;
    g.gain.setValueAtTime(gain, t0);
    g.gain.exponentialRampToValueAtTime(0.0001, t1);

    osc.connect(g);
    g.connect(ctx.destination);
    osc.start(t0);
    osc.stop(t1);
  } catch (_) {
    // یەک شکست نابێتە هۆی کوژاندنەوەی هەمیشەیی دەنگ.
  }
}
