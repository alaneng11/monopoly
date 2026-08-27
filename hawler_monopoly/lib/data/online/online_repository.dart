import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/game_models.dart';
import 'firebase_bootstrap.dart';
import 'models/room_models.dart';

/// ڕوونی هەڵەی ئۆنلاین.
class OnlineError {
  final String code;
  final String messageKu;
  const OnlineError(this.code, this.messageKu);
  @override
  String toString() => messageKu;
}

typedef RoomResult = Future<void> Function();

class RoomRepository {
  RoomRepository._();
  static final RoomRepository instance = RoomRepository._();

  static const _roomsPath = 'rooms';
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int codeLength = 5;

  final _rng = Random();

  Future<void> _ready() async {
    final s = await FirebaseSetup.ensureInitialized();
    if (s != FirebaseSetupStatus.ready) {
      throw OnlineError('FB_MISSING', FirebaseSetup.missingConfigMessage());
    }
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  String _uid() {
    final u = _user;
    if (u == null) throw const OnlineError('NOT_AUTH', 'سەرەتا بچۆرە ژوورەوە.');
    return u.uid;
  }

  String _genCode() {
    final sb = StringBuffer();
    for (var i = 0; i < codeLength; i++) {
      sb.write(_codeChars[_rng.nextInt(_codeChars.length)]);
    }
    return sb.toString();
  }

  /// دروستکردنی ژووری نوێ (گشتی یان تایبەت).
  Future<Room> createRoom({
    required String roomName,
    required String playerName,
    required String characterId,
    bool isPublic = false,
    int maxPlayers = 6,
    int startCash = 1500,
  }) async {
    await _ready();
    final uid = _uid();
    var code = _genCode();
    final db = FirebaseFirestore.instance;

    // دووبارە نەبوونی کۆد
    while ((await db.collection(_roomsPath).doc(code).get()).exists) {
      code = _genCode();
    }

    final host = RoomPlayer(
      id: uid,
      name: playerName,
      characterId: characterId,
      ready: false,
      joinedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final room = Room(
      code: code,
      hostId: uid,
      status: RoomStatus.lobby,
      players: [host],
      maxPlayers: maxPlayers,
      isPublic: isPublic,
      roomName: roomName,
      startCash: startCash,
      version: 1,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await db.collection(_roomsPath).doc(code).set(room.toJson());
    return room;
  }

  /// چوونەژوورەوە بە کۆد.
  Future<Room> joinRoom({
    required String code,
    required String playerName,
    required String characterId,
  }) async {
    await _ready();
    final uid = _uid();
    final db = FirebaseFirestore.instance;
    final ref = db.collection(_roomsPath).doc(code.toUpperCase());

    return db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const OnlineError('NOT_FOUND', 'ژوورەکە نەدۆزرایەوە.');
      final room = Room.fromJson(snap.data()!);

      if (room.status != RoomStatus.lobby) {
        throw const OnlineError('STARTED', 'یارییەکە دەستی پێکردووە.');
      }
      if (room.isFull) {
        throw const OnlineError('FULL', 'ژوورەکە پڕە.');
      }
      if (room.players.any((p) => p.id == uid)) {
        return room; // پێشتر چووەتەوە ژوورەوە
      }
      final player = RoomPlayer(
        id: uid,
        name: playerName,
        characterId: characterId,
        joinedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final updated = room.copyWith(players: [...room.players, player], version: room.version + 1);
      tx.update(ref, updated.toJson());
      return updated;
    });
  }

  /// گۆڕینی دۆخی ئامادەبوون.
  Future<void> setReady(String code, bool ready) async {
    await _ready();
    final uid = _uid();
    final db = FirebaseFirestore.instance;
    final ref = db.collection(_roomsPath).doc(code);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const OnlineError('NOT_FOUND', 'ژوورەکە نەدۆزرایەوە.');
      final room = Room.fromJson(snap.data()!);
      final players = room.players
          .map((p) => p.id == uid ? p.copyWith(ready: ready) : p)
          .toList();
      tx.update(ref, {
        'players': players.map((p) => p.toJson()).toList(),
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// دەستپێکردنی یاری (تەنها میوان).
  Future<void> startGame(String code) async {
    await _ready();
    final uid = _uid();
    final db = FirebaseFirestore.instance;
    final ref = db.collection(_roomsPath).doc(code);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw const OnlineError('NOT_FOUND', 'ژوورەکە نەدۆزرایەوە.');
      final room = Room.fromJson(snap.data()!);
      if (room.hostId != uid) {
        throw const OnlineError('NOT_HOST', 'تەنها میوان دەتوانێت یاری دەستپێبکات.');
      }
      if (room.players.length < 2) {
        throw const OnlineError('NEED_PLAYERS', 'لانی کەم ٢ یاریزان پێویستە.');
      }
      if (!room.canStart) {
        throw const OnlineError('NOT_READY', 'هەموو یاریزانەکان دەبێت ئامادە بن.');
      }
      tx.update(ref, {
        'status': RoomStatus.playing.name,
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// دەرچوون لە ژوور لەگەڵ گواستنەوەی میوانی.
  Future<void> leaveRoom(String code) async {
    await _ready();
    final uid = _uid();
    final db = FirebaseFirestore.instance;
    final ref = db.collection(_roomsPath).doc(code);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final room = Room.fromJson(snap.data()!);
      var players = room.players.where((p) => p.id != uid).toList();
      var hostId = room.hostId;
      if (hostId == uid && players.isNotEmpty) {
        hostId = players.first.id; // گواستنەوەی میوانی
      }
      final status = players.isEmpty ? RoomStatus.closed : room.status;
      tx.update(ref, {
        'players': players.map((p) => p.toJson()).toList(),
        'hostId': hostId,
        'status': status.name,
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// گوێگرتن لە گۆڕانکاری ژوور.
  Stream<Room> watchRoom(String code) {
    final db = FirebaseFirestore.instance;
    return db.collection(_roomsPath).doc(code).snapshots().map((s) {
      if (!s.exists) throw const OnlineError('CLOSED', 'ژوورەکە داخراوە.');
      return Room.fromJson(s.data()!);
    });
  }
}

/// هاوکاتسازی یاری ئۆنلاین بە Firestore.
class GameSyncRepository {
  GameSyncRepository._();
  static final GameSyncRepository instance = GameSyncRepository._();

  static const _gamesPath = 'games';

  Future<void> _ready() async {
    final s = await FirebaseSetup.ensureInitialized();
    if (s != FirebaseSetupStatus.ready) {
      throw OnlineError('FB_MISSING', FirebaseSetup.missingConfigMessage());
    }
  }

  /// دروستکردنی دۆخی یاری نوێ (لەلایەن میوانەوە).
  Future<void> initGame(String roomCode, GameState state) async {
    await _ready();
    final db = FirebaseFirestore.instance;
    await db.collection(_gamesPath).doc(roomCode).set({
      'round': state.round,
      'currentPlayerIndex': state.currentPlayerIndex,
      'phase': state.phase.name,
      'dice': state.dice,
      'players': state.players.map((p) => p.toJson()).toList(),
      'tiles': state.tiles.values.map((t) => t.toJson()).toList(),
      'freeCoins': state.freeCoins,
      'winnerId': state.winnerId,
      'seed': state.seed,
      'turnToken': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// گوێگرتن لە دۆخی یاری.
  Stream<GameState?> watchGame(String roomCode, List<TileDefinition> board) {
    final db = FirebaseFirestore.instance;
    return db.collection(_gamesPath).doc(roomCode).snapshots().map((s) {
      if (!s.exists) return null;
      final j = s.data()!;
      final players = ((j['players'] as List?) ?? [])
          .map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList();
      final tiles = <int, TileState>{};
      for (final t in ((j['tiles'] as List?) ?? [])) {
        final ts = TileState.fromJson(t as Map<String, dynamic>);
        tiles[ts.tileIndex] = ts;
      }
      return GameState(
        board: board,
        players: players,
        tiles: tiles,
        round: (j['round'] as num?)?.toInt() ?? 1,
        currentPlayerIndex: (j['currentPlayerIndex'] as num?)?.toInt() ?? 0,
        phase: GamePhase.values.firstWhere(
          (p) => p.name == j['phase'],
          orElse: () => GamePhase.awaitingRoll,
        ),
        dice: ((j['dice'] as List?) ?? [1, 1]).cast<num>().map((e) => e.toInt()).toList(),
        freeCoins: (j['freeCoins'] as num?)?.toInt() ?? 0,
        winnerId: j['winnerId'] as String? ?? '',
        startedAt: DateTime.now(),
        seed: (j['seed'] as num?)?.toInt() ?? 1,
      );
    });
  }

  /// نوێکردنەوەی دۆخ لەگەڵ ژمارەی سووڕ (بۆ ڕێگرتن لە نووسینەوەی دووبارە).
  Future<void> commitState(String roomCode, GameState state) async {
    await _ready();
    final db = FirebaseFirestore.instance;
    await db.collection(_gamesPath).doc(roomCode).update({
      'round': state.round,
      'currentPlayerIndex': state.currentPlayerIndex,
      'phase': state.phase.name,
      'dice': state.dice,
      'players': state.players.map((p) => p.toJson()).toList(),
      'tiles': state.tiles.values.map((t) => t.toJson()).toList(),
      'freeCoins': state.freeCoins,
      'winnerId': state.winnerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
