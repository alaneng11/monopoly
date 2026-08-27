import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/persistence.dart';

class ProfileState {
  final Map<String, dynamic> data;
  const ProfileState(this.data);

  String get name => data['name'] as String? ?? 'یاریزان';
  String get username => data['username'] as String? ?? 'player';
  int get coins => data['coins'] as int? ?? 0;
  int get gems => data['gems'] as int? ?? 0;
  int get xp => data['xp'] as int? ?? 0;
  int get level => data['level'] as int? ?? 1;
  int get wins => data['wins'] as int? ?? 0;
  int get games => data['games'] as int? ?? 0;
  int get streak => data['streak'] as int? ?? 0;
  double get winRate => games == 0 ? 0 : wins / games;
  int get xpInLevel => xp % 1000;

  ProfileState copyWith(Map<String, dynamic> patch) =>
      ProfileState({...data, ...patch});
}

class ProfileController extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async {
    final p = await LocalPersistence.loadProfile();
    return ProfileState(p);
  }

  Future<void> refresh() async {
    state = AsyncData(ProfileState(await LocalPersistence.loadProfile()));
  }

  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final cur = state.value;
    if (cur == null) return;
    final next = cur.copyWith(patch);
    state = AsyncData(next);
    await LocalPersistence.saveProfile(next.data);
  }

  Future<void> addCoins(int amount) async {
    final cur = state.value;
    if (cur == null) return;
    await updateProfile({'coins': cur.coins + amount});
  }

  Future<void> setName(String name) async {
    if (name.trim().isEmpty) return;
    await updateProfile({'name': name.trim()});
  }
}

final profileProvider = AsyncNotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class SettingsState {
  final Map<String, dynamic> data;
  const SettingsState(this.data);

  bool get sound => data['sound'] as bool? ?? true;
  bool get music => data['music'] as bool? ?? true;
  bool get notifications => data['notifications'] as bool? ?? false;
  bool get vibration => data['vibration'] as bool? ?? true;

  SettingsState copyWith(Map<String, dynamic> patch) => SettingsState({...data, ...patch});
}

class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    return SettingsState(await LocalPersistence.loadSettings());
  }

  Future<void> set(String key, bool value) async {
    final cur = state.value;
    if (cur == null) return;
    final next = cur.copyWith({key: value});
    state = AsyncData(next);
    await LocalPersistence.saveSettings(next.data);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsController, SettingsState>(SettingsController.new);

// ---------------- دەستکەوتەکان ----------------

class AchievementDef {
  final String id;
  final String title;
  final String description;
  const AchievementDef(this.id, this.title, this.description);
}

const List<AchievementDef> allAchievements = [
  AchievementDef('first_win', 'یەکەم سەرکەوتن', 'یەکەم یاری خۆت ببەیتەوە'),
  AchievementDef('monopoly', 'خاوەنی گەڕەک', 'هەموو خانەکانی یەک ڕەنگ بکڕیت'),
  AchievementDef('landmark', 'شوێنی گرنگ', 'قەڵای هەولێر بکڕیت'),
  AchievementDef('rich', 'زەنگین', '١٠٠٠٠ زێڕ کۆبکەیتەوە'),
  AchievementDef('trader', 'بازرگان', 'یەکەم بازرگانی تەواو بکەیت'),
];

class AchievementsController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async => LocalPersistence.loadAchievements();

  Future<void> unlock(String id) async {
    final cur = state.value ?? [];
    if (cur.contains(id)) return;
    final next = [...cur, id];
    state = AsyncData(next);
    await LocalPersistence.saveAchievements(next);
  }
}

final achievementsProvider = AsyncNotifierProvider<AchievementsController, List<String>>(AchievementsController.new);

// ---------------- چالێنژەکان (Challenges) ----------------

class ChallengeProgress {
  final Map<String, int> progress;
  const ChallengeProgress(this.progress);

  int getProgress(String id) => progress[id] ?? 0;
  bool isCompleted(String id, int target) => (progress[id] ?? 0) >= target;
  ChallengeProgress increment(String id, [int amount = 1]) => ChallengeProgress({
    ...progress,
    id: (progress[id] ?? 0) + amount,
  });
}

class ChallengeController extends AsyncNotifier<ChallengeProgress> {
  @override
  Future<ChallengeProgress> build() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('challenge_progress');
    if (raw == null) return const ChallengeProgress({});
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return ChallengeProgress(map.map((k, v) => MapEntry(k, v as int)));
    } catch (_) {
      return const ChallengeProgress({});
    }
  }

  Future<void> incrementProgress(String id, [int amount = 1]) async {
    final cur = state.value ?? const ChallengeProgress({});
    final next = cur.increment(id, amount);
    state = AsyncData(next);
    final p = await SharedPreferences.getInstance();
    await p.setString('challenge_progress', jsonEncode(next.progress));
  }

  Future<void> resetDaily() async {
    state = const AsyncData(ChallengeProgress({}));
    final p = await SharedPreferences.getInstance();
    await p.remove('challenge_progress');
  }
}

final challengeProvider = AsyncNotifierProvider<ChallengeController, ChallengeProgress>(ChallengeController.new);

// ---------------- تۆماری یارییەکان (Match History) ----------------

class MatchHistoryController extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('match_history') ?? [];
    return raw.map((s) {
      try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
    }).where((m) => m.isNotEmpty).toList();
  }

  Future<void> addRecord(Map<String, dynamic> record) async {
    final cur = state.value ?? [];
    final next = [record, ...cur].take(50).toList();
    state = AsyncData(next);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('match_history', next.map((m) => jsonEncode(m)).toList());
  }
}

final matchHistoryProvider = AsyncNotifierProvider<MatchHistoryController, List<Map<String, dynamic>>>(MatchHistoryController.new);

// ---------------- دۆخی هەفتانە ----------------

class WeeklyState {
  final Map<String, dynamic> data;
  const WeeklyState(this.data);

  String get lastClaim => data['lastClaim'] as String? ?? '';
  int get week => data['week'] as int? ?? 0;

  WeeklyState copyWith(Map<String, dynamic> patch) => WeeklyState({...data, ...patch});
}

class WeeklyController extends AsyncNotifier<WeeklyState> {
  @override
  Future<WeeklyState> build() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('weekly');
    if (raw == null) return const WeeklyState({});
    try {
      return WeeklyState(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const WeeklyState({});
    }
  }

  Future<void> updateState(Map<String, dynamic> patch) async {
    final cur = state.value ?? const WeeklyState({});
    final next = cur.copyWith(patch);
    state = AsyncData(next);
    final p = await SharedPreferences.getInstance();
    await p.setString('weekly', jsonEncode(next.data));
  }
}

final weeklyProvider = AsyncNotifierProvider<WeeklyController, WeeklyState>(WeeklyController.new);
