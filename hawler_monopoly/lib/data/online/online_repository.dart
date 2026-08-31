import 'dart:async';

import '../../domain/models/game_models.dart';
import 'api_client.dart';
import 'models/room_models.dart';
import 'web_socket_service.dart';

/// ڕوونی هەڵەی ئۆنلاین.
class OnlineError {
  final String code;
  final String messageKu;
  const OnlineError(this.code, this.messageKu);
  @override
  String toString() => messageKu;
}

class RoomRepository {
  RoomRepository._();
  static final RoomRepository instance = RoomRepository._();

  final Map<String, StreamController<Room>> _roomControllers = {};
  final Map<String, Timer> _roomPollTimers = {};

  String get currentUserId => ApiClient.instance.currentUserId;

  /// دروستکردنی ژووری نوێ لە سێرڤەری Railway.
  Future<Room> createRoom({
    required String roomName,
    required String playerName,
    required String characterId,
    bool isPublic = false,
    int maxPlayers = 6,
    int startCash = 1500,
  }) async {
    final result = await ApiClient.instance.createRoom(
      roomName: roomName,
      isPublic: isPublic,
      maxPlayers: maxPlayers,
      startCash: startCash,
    );

    if (!result.ok || result.data == null) {
      throw OnlineError('CREATE_FAILED', result.error ?? 'دروستکردنی ژوور سەرکەوتوو نەبوو.');
    }

    final roomData = result.data!['room'] as Map<String, dynamic>;
    final room = Room.fromJson(roomData);
    WebSocketService.instance.joinRoom(room.code);
    return room;
  }

  /// چوونەژوورەوە بە کۆد.
  Future<Room> joinRoom({
    required String code,
    required String playerName,
    required String characterId,
  }) async {
    final result = await ApiClient.instance.joinRoom(code.toUpperCase());
    if (!result.ok || result.data == null) {
      throw OnlineError('JOIN_FAILED', result.error ?? 'چوونەژوورەوە سەرکەوتوو نەبوو.');
    }

    final roomData = result.data!['room'] as Map<String, dynamic>;
    final room = Room.fromJson(roomData);
    WebSocketService.instance.joinRoom(room.code);
    return room;
  }

  /// گۆڕینی دۆخی ئامادەبوون.
  Future<void> setReady(String code, bool ready) async {
    final result = await ApiClient.instance.readyRoom(code.toUpperCase(), ready);
    if (!result.ok) {
      throw OnlineError('READY_FAILED', result.error ?? 'گۆڕینی ئامادەبوون سەرکەوتوو نەبوو.');
    }
  }

  /// دەستپێکردنی یاری (تەنها میوان).
  Future<void> startGame(String code) async {
    final result = await ApiClient.instance.startGame(code.toUpperCase());
    if (!result.ok) {
      throw OnlineError('START_FAILED', result.error ?? 'دەستپێکردنی یاری سەرکەوتوو نەبوو.');
    }
  }

  /// دەرچوون لە ژوور.
  Future<void> leaveRoom(String code) async {
    final cleanCode = code.toUpperCase();
    WebSocketService.instance.leaveRoom();
    _roomPollTimers[cleanCode]?.cancel();
    _roomPollTimers.remove(cleanCode);
    await ApiClient.instance.leaveRoom(cleanCode);
  }

  /// لیستی ژوورە گشتییەکان.
  Future<List<Map<String, dynamic>>> getPublicRooms() async {
    final result = await ApiClient.instance.getPublicRooms();
    if (result.ok && result.data != null) {
      final list = result.data!['rooms'] as List?;
      return list?.cast<Map<String, dynamic>>() ?? [];
    }
    return [];
  }

  /// گوێگرتن لە گۆڕانکاری ژوور بە شێوەی ڕاستەوخۆ.
  Stream<Room> watchRoom(String code) {
    final cleanCode = code.toUpperCase();
    final controller = _roomControllers.putIfAbsent(
      cleanCode,
      () => StreamController<Room>.broadcast(),
    );

    // Initial fetch
    _fetchRoom(cleanCode);

    // Fast periodic poll fallback
    _roomPollTimers[cleanCode]?.cancel();
    _roomPollTimers[cleanCode] = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _fetchRoom(cleanCode);
    });

    // Make sure we are joined to WebSocket room
    WebSocketService.instance.joinRoom(cleanCode);

    // WebSocket live event listener
    _roomSub?.cancel();
    _roomSub = WebSocketService.instance.onRoomUpdated.listen((event) {
      final eventCode = (event['roomCode'] ?? (event['room']?['code']))?.toString().toUpperCase();
      if (eventCode == null || eventCode == cleanCode) {
        final roomData = event['room'] as Map<String, dynamic>?;
        if (roomData != null) {
          controller.add(Room.fromJson(roomData));
        } else {
          _fetchRoom(cleanCode);
        }
      }
    });

    return controller.stream;
  }

  StreamSubscription? _roomSub;

  Future<void> _fetchRoom(String code) async {
    final result = await ApiClient.instance.getRoom(code);
    if (result.ok && result.data != null) {
      final roomData = result.data!['room'] as Map<String, dynamic>?;
      if (roomData != null) {
        _roomControllers[code]?.add(Room.fromJson(roomData));
      }
    }
  }
}

/// هاوکاتسازی یاری ئۆنلاین بە ڕێگەی سێرڤەری Railway و WebSocket.
class GameSyncRepository {
  GameSyncRepository._();
  static final GameSyncRepository instance = GameSyncRepository._();

  final Map<String, StreamController<GameState?>> _gameControllers = {};
  final Map<String, Timer> _gamePollTimers = {};
  StreamSubscription? _gameEventsSub;

  /// وەرگرتن و گوێگرتن لە دۆخی یاری.
  Stream<GameState?> watchGame(String roomCode, List<TileDefinition> board) {
    final cleanCode = roomCode.toUpperCase();
    final controller = _gameControllers.putIfAbsent(
      cleanCode,
      () => StreamController<GameState?>.broadcast(),
    );

    _fetchGameState(cleanCode, board);

    _gamePollTimers[cleanCode]?.cancel();
    _gamePollTimers[cleanCode] = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _fetchGameState(cleanCode, board);
    });

    WebSocketService.instance.joinRoom(cleanCode);

    // Listen to WebSocket game updates
    _gameEventsSub?.cancel();
    _gameEventsSub = WebSocketService.instance.onGameStateUpdate.listen((event) {
      final stateData = (event['state'] ?? event) as Map<String, dynamic>?;
      if (stateData != null) {
        final eventRoom = (stateData['roomCode'] ?? stateData['room_code'] ?? event['roomCode'])?.toString().toUpperCase();
        if (eventRoom == null || eventRoom == cleanCode) {
          parseAndEmit(cleanCode, stateData, board);
        }
      } else {
        _fetchGameState(cleanCode, board);
      }
    });

    return controller.stream;
  }

  Future<void> _fetchGameState(String roomCode, List<TileDefinition> board) async {
    final result = await ApiClient.instance.getGameState(roomCode);
    if (result.ok && result.data != null) {
      parseAndEmit(roomCode, result.data!, board);
    }
  }

  void parseAndEmit(String roomCode, Map<String, dynamic> j, List<TileDefinition> board) {
    try {
      final rawPlayers = (j['players'] is String)
          ? []
          : ((j['players'] as List?) ?? []);
      
      final players = rawPlayers.map((p) {
        final pMap = p as Map<String, dynamic>;
        return Player(
          id: (pMap['id'] ?? pMap['user_id']) as String? ?? '',
          name: (pMap['name'] ?? pMap['displayName'] ?? pMap['display_name']) as String? ?? 'یاریزان',
          colorIndex: (pMap['colorIndex'] ?? pMap['color_index'] as num?)?.toInt() ?? 0,
          characterId: (pMap['characterId'] ?? pMap['character_id']) as String? ?? 'business',
          cash: (pMap['cash'] as num?)?.toInt() ?? 1500,
          position: (pMap['position'] as num?)?.toInt() ?? 0,
          inJail: pMap['in_jail'] == true || pMap['inJail'] == true,
          jailTurns: (pMap['jailTurns'] ?? pMap['jail_turns'] as num?)?.toInt() ?? 0,
          doublesInARow: (pMap['doublesInARow'] ?? pMap['doubles_in_a_row'] as num?)?.toInt() ?? 0,
          propertiesOwned: (pMap['propertiesOwned'] ?? pMap['properties_owned'] as num?)?.toInt() ?? 0,
          bankrupt: pMap['bankrupt'] == true,
        );
      }).toList();

      final rawDice = j['dice'];
      List<int> dice = [1, 1];
      if (rawDice is List) {
        dice = rawDice.map((d) => (d as num).toInt()).toList();
      }

      final phaseStr = j['phase'] as String? ?? 'awaitingRoll';
      final phase = GamePhase.values.firstWhere(
        (p) => p.name == phaseStr,
        orElse: () => GamePhase.awaitingRoll,
      );

      final rawTiles = (j['tiles'] is Map) ? (j['tiles'] as Map<String, dynamic>) : <String, dynamic>{};
      final Map<int, TileState> tiles = {};
      rawTiles.forEach((key, val) {
        final idx = int.tryParse(key.toString());
        if (idx != null && val is Map<String, dynamic>) {
          tiles[idx] = TileState(
            tileIndex: (val['tileIndex'] ?? val['tile_index'] as num?)?.toInt() ?? idx,
            ownerId: (val['ownerId'] ?? val['owner_id']) as String?,
            level: (val['level'] as num?)?.toInt() ?? 0,
            mortgaged: val['mortgaged'] == true || val['mortgaged'] == 1,
          );
        }
      });

      final state = GameState(
        board: board,
        players: players,
        tiles: tiles,
        round: (j['round'] as num?)?.toInt() ?? 1,
        currentPlayerIndex: (j['currentPlayerIndex'] ?? j['current_player_index'] as num?)?.toInt() ?? 0,
        phase: phase,
        dice: dice,
        freeCoins: (j['freeCoins'] ?? j['free_coins'] as num?)?.toInt() ?? 0,
        winnerId: (j['winnerId'] ?? j['winner_id']) as String? ?? '',
        startedAt: DateTime.now(),
        seed: (j['seed'] as num?)?.toInt() ?? 1,
        diceMultiplier: (j['diceMultiplier'] ?? j['dice_multiplier'] as num?)?.toInt() ?? 1,
        diceEnergy: (j['diceEnergy'] ?? j['dice_energy'] as num?)?.toInt() ?? 10,
        maxDiceEnergy: (j['maxDiceEnergy'] ?? j['max_dice_energy'] as num?)?.toInt() ?? 10,
        turnStartedAt: (j['turnStartedAt'] ?? j['turn_started_at'] as num?)?.toInt(),
      );

      _gameControllers[roomCode]?.add(state);
    } catch (_) {}
  }
}

// ── Rewards Repository ──────────────────────────────────────────

class DailyRewardItem {
  final int dayNumber;
  final int coinReward;
  final int gemReward;
  final int diceReward;
  final int xpReward;
  final String description;
  final bool isClaimed;

  DailyRewardItem({
    required this.dayNumber,
    required this.coinReward,
    required this.gemReward,
    required this.diceReward,
    required this.xpReward,
    required this.description,
    required this.isClaimed,
  });

  factory DailyRewardItem.fromJson(Map<String, dynamic> j) => DailyRewardItem(
        dayNumber: (j['dayNumber'] ?? j['day_number'] as num?)?.toInt() ?? 1,
        coinReward: (j['coinReward'] ?? j['coin_reward'] as num?)?.toInt() ?? 0,
        gemReward: (j['gemReward'] ?? j['gem_reward'] as num?)?.toInt() ?? 0,
        diceReward: (j['diceReward'] ?? j['dice_reward'] as num?)?.toInt() ?? 0,
        xpReward: (j['xpReward'] ?? j['xp_reward'] as num?)?.toInt() ?? 0,
        description: (j['description'] as String?) ?? '',
        isClaimed: j['isClaimed'] == true || j['is_claimed'] == true,
      );
}

class MissionItem {
  final String id;
  final String title;
  final String description;
  final String period;
  final int target;
  final String actionType;
  final int xpReward;
  final int coinReward;
  final int diceReward;
  final int progress;
  final bool isCompleted;
  final bool isClaimed;

  MissionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.target,
    required this.actionType,
    required this.xpReward,
    required this.coinReward,
    required this.diceReward,
    required this.progress,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory MissionItem.fromJson(Map<String, dynamic> j) => MissionItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        period: j['period'] as String? ?? 'daily',
        target: (j['target'] as num?)?.toInt() ?? 1,
        actionType: (j['actionType'] ?? j['action_type']) as String? ?? '',
        xpReward: (j['xpReward'] ?? j['xp_reward'] as num?)?.toInt() ?? 0,
        coinReward: (j['coinReward'] ?? j['coin_reward'] as num?)?.toInt() ?? 0,
        diceReward: (j['diceReward'] ?? j['dice_reward'] as num?)?.toInt() ?? 0,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        isCompleted: j['isCompleted'] == true || j['is_completed'] == true,
        isClaimed: j['isClaimed'] == true || j['is_claimed'] == true,
      );
}

class RewardsRepository {
  RewardsRepository._();
  static final instance = RewardsRepository._();

  Future<List<DailyRewardItem>> getDailyRewards() async {
    final res = await ApiClient.instance.getDailyRewards();
    if (res.ok && res.data != null && res.data!['rewards'] != null) {
      final list = res.data!['rewards'] as List;
      return list.map((i) => DailyRewardItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<bool> claimDailyReward(int dayNumber) async {
    final res = await ApiClient.instance.claimDailyReward(dayNumber);
    return res.ok;
  }

  Future<List<MissionItem>> getMissions() async {
    final res = await ApiClient.instance.getMissions();
    if (res.ok && res.data != null && res.data!['missions'] != null) {
      final list = res.data!['missions'] as List;
      return list.map((i) => MissionItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<bool> claimMission(String missionId) async {
    final res = await ApiClient.instance.claimMission(missionId);
    return res.ok;
  }
}

// ── Shop Repository ─────────────────────────────────────────────

class CosmeticItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final String rarity;
  final int coinPrice;
  final int gemPrice;
  final String icon;
  final String previewAsset;
  final bool isEquipped;

  CosmeticItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.coinPrice,
    required this.gemPrice,
    required this.icon,
    required this.previewAsset,
    this.isEquipped = false,
  });

  factory CosmeticItem.fromJson(Map<String, dynamic> j) => CosmeticItem(
        id: (j['id'] ?? j['cosmeticId'] ?? j['cosmetic_id']) as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        category: j['category'] as String? ?? 'dice',
        rarity: j['rarity'] as String? ?? 'common',
        coinPrice: (j['coinPrice'] ?? j['coin_price'] as num?)?.toInt() ?? 0,
        gemPrice: (j['gemPrice'] ?? j['gem_price'] as num?)?.toInt() ?? 0,
        icon: j['icon'] as String? ?? '🎲',
        previewAsset: (j['previewAsset'] ?? j['preview_asset']) as String? ?? '',
        isEquipped: j['isEquipped'] == true || j['is_equipped'] == true,
      );
}

class ShopRepository {
  ShopRepository._();
  static final instance = ShopRepository._();

  Future<List<CosmeticItem>> getCatalog() async {
    final res = await ApiClient.instance.getShopCatalog();
    if (res.ok && res.data != null && res.data!['items'] != null) {
      final list = res.data!['items'] as List;
      return list.map((i) => CosmeticItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<CosmeticItem>> getInventory() async {
    final res = await ApiClient.instance.getInventory();
    if (res.ok && res.data != null && res.data!['inventory'] != null) {
      final list = res.data!['inventory'] as List;
      return list.map((i) => CosmeticItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<bool> buyItem(String id, {String currency = 'coins'}) async {
    final res = await ApiClient.instance.buyCosmetic(id, currency: currency);
    return res.ok;
  }

  Future<bool> equipItem(String id) async {
    final res = await ApiClient.instance.equipCosmetic(id);
    return res.ok;
  }
}

// ── Match History Repository ────────────────────────────────────

class MatchHistoryItem {
  final int id;
  final String roomCode;
  final String winnerId;
  final String winnerName;
  final List<String> playerNames;
  final int round;
  final int durationSeconds;
  final int finalNetWorth;
  final int playedAt;

  MatchHistoryItem({
    required this.id,
    required this.roomCode,
    required this.winnerId,
    required this.winnerName,
    required this.playerNames,
    required this.round,
    required this.durationSeconds,
    required this.finalNetWorth,
    required this.playedAt,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> j) => MatchHistoryItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        roomCode: (j['roomCode'] ?? j['room_code']) as String? ?? '',
        winnerId: (j['winnerId'] ?? j['winner_id']) as String? ?? '',
        winnerName: (j['winnerName'] ?? j['winner_name']) as String? ?? 'یاریزان',
        playerNames: ((j['playerNames'] ?? j['player_names']) as List?)?.map((e) => e.toString()).toList() ?? [],
        round: (j['round'] as num?)?.toInt() ?? 0,
        durationSeconds: (j['durationSeconds'] ?? j['duration_seconds'] as num?)?.toInt() ?? 0,
        finalNetWorth: (j['finalNetWorth'] ?? j['final_net_worth'] as num?)?.toInt() ?? 0,
        playedAt: (j['playedAt'] ?? j['played_at'] as num?)?.toInt() ?? 0,
      );
}

class MatchHistoryRepository {
  MatchHistoryRepository._();
  static final instance = MatchHistoryRepository._();

  Future<List<MatchHistoryItem>> getHistory({int page = 1, int limit = 20}) async {
    final res = await ApiClient.instance.getMatchHistory(page: page, limit: limit);
    if (res.ok && res.data != null && res.data!['matches'] != null) {
      final list = res.data!['matches'] as List;
      return list.map((i) => MatchHistoryItem.fromJson(i as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

