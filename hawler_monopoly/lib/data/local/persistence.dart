import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/game_models.dart';

/// پاشکەوتی ناوخۆیی — پرۆفایل، ڕێکخستنەکان، خەڵاتی ڕۆژانە، پێشکەوتن،
/// و پاشەکەوتی دۆخی یاری بۆ دەستپێکردنەوە.
class LocalPersistence {
  LocalPersistence._();
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  // ---------------- پرۆفایل ----------------

  static Future<Map<String, dynamic>> loadProfile() async {
    final p = await _p;
    final raw = p.getString('profile');
    if (raw == null) {
      return {
        'name': 'یاریزان',
        'username': 'hawler_player',
        'coins': 3000,
        'gems': 20,
        'xp': 0,
        'level': 1,
        'wins': 0,
        'games': 0,
        'streak': 0,
      };
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final p = await _p;
    await p.setString('profile', jsonEncode(profile));
  }

  // ---------------- ڕێکخستنەکان ----------------

  static Future<Map<String, dynamic>> loadSettings() async {
    final p = await _p;
    final raw = p.getString('settings');
    if (raw == null) {
      return {'sound': true, 'music': true, 'notifications': false, 'vibration': true};
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final p = await _p;
    await p.setString('settings', jsonEncode(settings));
  }

  // ---------------- خەڵاتی ڕۆژانە ----------------

  static Future<Map<String, dynamic>> loadDailyReward() async {
    final p = await _p;
    final raw = p.getString('daily');
    if (raw == null) return {'lastClaim': '', 'day': 0};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveDailyReward(Map<String, dynamic> daily) async {
    final p = await _p;
    await p.setString('daily', jsonEncode(daily));
  }

  // ---------------- دەستکەوتەکان ----------------

  static Future<List<String>> loadAchievements() async {
    final p = await _p;
    return p.getStringList('achievements') ?? [];
  }

  static Future<void> saveAchievements(List<String> ids) async {
    final p = await _p;
    await p.setStringList('achievements', ids);
  }

  // ---------------- پاشەکەوتی یاری ----------------

  static Future<void> saveGame(GameState s) async {
    final p = await _p;
    await p.setString('saved_game', jsonEncode(_serialize(s)));
  }

  static Future<void> clearGame() async {
    final p = await _p;
    await p.remove('saved_game');
  }

  static Future<Map<String, dynamic>?> loadGame() async {
    final p = await _p;
    final raw = p.getString('saved_game');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _serialize(GameState s) => {
        'round': s.round,
        'currentPlayerIndex': s.currentPlayerIndex,
        'phase': s.phase.name,
        'dice': s.dice,
        'players': s.players.map((p) => p.toJson()).toList(),
        'tiles': s.tiles.values.map((t) => t.toJson()).toList(),
        'freeCoins': s.freeCoins,
        'winnerId': s.winnerId,
        'seed': s.seed,
        'diceMultiplier': s.diceMultiplier,
        'diceEnergy': s.diceEnergy,
        'maxDiceEnergy': s.maxDiceEnergy,
        'energyRegenRate': s.energyRegenRate,
        'completedChallenges': s.completedChallenges.map((c) => c.toJson()).toList(),
        'matchHistory': s.matchHistory.map((m) => m.toJson()).toList(),
      };

  static GameState deserialize(Map<String, dynamic> j, List<TileDefinition> board) {
    final players = (j['players'] as List).map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
    final tiles = <int, TileState>{};
    for (final t in (j['tiles'] as List)) {
      final ts = TileState.fromJson(t as Map<String, dynamic>);
      tiles[ts.tileIndex] = ts;
    }
    final challenges = <CompletedChallenge>[];
    for (final c in ((j['completedChallenges'] as List?) ?? [])) {
      challenges.add(CompletedChallenge.fromJson(c as Map<String, dynamic>));
    }
    final history = <MatchRecord>[];
    for (final m in ((j['matchHistory'] as List?) ?? [])) {
      history.add(MatchRecord.fromJson(m as Map<String, dynamic>));
    }
    return GameState(
      board: board,
      players: players,
      tiles: tiles,
      round: j['round'] as int? ?? 1,
      currentPlayerIndex: j['currentPlayerIndex'] as int? ?? 0,
      phase: GamePhase.values.firstWhere(
        (p) => p.name == j['phase'],
        orElse: () => GamePhase.awaitingRoll,
      ),
      dice: (j['dice'] as List?)?.cast<int>() ?? const [1, 1],
      freeCoins: j['freeCoins'] as int? ?? 0,
      winnerId: j['winnerId'] as String? ?? '',
      diceMultiplier: j['diceMultiplier'] as int? ?? 1,
      diceEnergy: j['diceEnergy'] as int? ?? 10,
      maxDiceEnergy: j['maxDiceEnergy'] as int? ?? 10,
      energyRegenRate: j['energyRegenRate'] as int? ?? 1,
      completedChallenges: challenges,
      matchHistory: history,
      startedAt: DateTime.now(),
      seed: j['seed'] as int? ?? 1,
    );
  }
}
