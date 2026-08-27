import 'package:firebase_core/firebase_core.dart';

/// دۆخی ڕێکخستنی Firebase.
enum FirebaseSetupStatus { ready, notConfigured, failed }

class FirebaseSetup {
  FirebaseSetup._();

  static FirebaseSetupStatus _status = FirebaseSetupStatus.notConfigured;
  static FirebaseSetupStatus get status => _status;
  static String lastError = '';

  static bool get isReady => _status == FirebaseSetupStatus.ready;

  /// هەوڵی دەستپێکردنی Firebase دەدات.
  /// ئەگەر فایلی ڕێکخستن (`firebase_options.dart` لە ڕێگەی flutterfire CLI)
  /// نەبوو، دۆخەکە دەبێتە [FirebaseSetupStatus.notConfigured] و
  /// ڕوونکردنەوەی تەواو دەگەڕێنێتەوە.
  ///
  /// ── داواکارییە دەرەکییەکان ──────────────────────────────────────────
  /// بۆ بەکارخستنی یاریی ئۆنلاین پێویستە:
  ///  1) پڕۆژەیەکی Firebase دروست بکرێت (console.firebase.google.com)
  ///  2) Authentication چالاک بکرێت (Anonymous یان Email)
  ///  3) Cloud Firestore دروست بکرێت
  ///  4) flutterfire CLI دامەزرێت:
  ///       dart pub global activate flutterfire_cli
  ///     پاشان لە پڕۆژەکەدا:
  ///       flutterfire configure
  ///     ئەمە فایلی lib/firebase_options.dart دروست دەکات.
  /// ──────────────────────────────────────────────────────────────────
  static Future<FirebaseSetupStatus> ensureInitialized() async {
    if (_status == FirebaseSetupStatus.ready) return _status;
    try {
      if (Firebase.apps.isNotEmpty) {
        _status = FirebaseSetupStatus.ready;
        return _status;
      }
      await Firebase.initializeApp();
      _status = FirebaseSetupStatus.ready;
    } catch (e) {
      lastError = e.toString();
      _status = FirebaseSetupStatus.notConfigured;
    }
    return _status;
  }

  /// ڕوونکردنەوەی کوردی بۆ نەبوونی ڕێکخستن.
  static String missingConfigMessage() =>
      'یاریی ئۆنلاین پێویستی بە پڕۆژەی Firebase هەیە.\n\n'
      'هەنگاوەکان:\n'
      '١. پڕۆژەیەک دروست بکە لە console.firebase.google.com\n'
      '٢. Authentication و Cloud Firestore چالاک بکە\n'
      '٣. flutterfire CLI دامەزرێنە:\n'
      '    dart pub global activate flutterfire_cli\n'
      '٤. لەناو پڕۆژەکەدا فەرمانەکە جێبەجێ بکە:\n'
      '    flutterfire configure\n\n'
      'پاشان ئەپەکە خۆکارانە ئۆنلاین دەبێت.';
}
