/// دۆخی نا-وێب — هیچ دەنگێکی سینتێسایزکراو نییە.
/// (لە مۆبایل/دێسکتۆپدا تەنها لەرین بەکاردێت.)
bool get audioSupported => false;

void playTone({
  required double frequency,
  required int durationMs,
  required double gain,
  required String type,
}) {}

void resumeAudio() {}
