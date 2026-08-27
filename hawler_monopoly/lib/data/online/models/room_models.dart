import '../../../domain/game_engine.dart';
import '../../../domain/models/game_models.dart';

enum RoomStatus { lobby, playing, closed }

class RoomPlayer {
  final String id;
  final String name;
  final String characterId;
  final bool ready;
  final bool connected;
  final int joinedAt;

  const RoomPlayer({
    required this.id,
    required this.name,
    required this.characterId,
    this.ready = false,
    this.connected = true,
    this.joinedAt = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'characterId': characterId,
        'ready': ready,
        'connected': connected,
        'joinedAt': joinedAt,
      };

  RoomPlayer copyWith({bool? ready, bool? connected}) => RoomPlayer(
        id: id,
        name: name,
        characterId: characterId,
        ready: ready ?? this.ready,
        connected: connected ?? this.connected,
        joinedAt: joinedAt,
      );

  static RoomPlayer fromJson(Map<String, dynamic> j) => RoomPlayer(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        characterId: j['characterId'] as String? ?? 'business',
        ready: j['ready'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
        joinedAt: (j['joinedAt'] as num?)?.toInt() ?? 0,
      );

  PlayerSetup toSetup() => PlayerSetup(
        id: id,
        name: name,
        characterId: characterId,
        kind: PlayerKind.human,
      );
}

class Room {
  final String code;
  final String hostId;
  final RoomStatus status;
  final List<RoomPlayer> players;
  final int maxPlayers;
  final bool isPublic;
  final String roomName;
  final int startCash;
  final int version;
  final int createdAt;
  final int updatedAt;

  const Room({
    required this.code,
    required this.hostId,
    required this.status,
    required this.players,
    this.maxPlayers = 6,
    this.isPublic = false,
    this.roomName = '',
    this.startCash = 1500,
    this.version = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= 2 && players.every((p) => p.ready || p.id == hostId);

  Room copyWith({
    String? hostId,
    RoomStatus? status,
    List<RoomPlayer>? players,
    int? version,
  }) =>
      Room(
        code: code,
        hostId: hostId ?? this.hostId,
        status: status ?? this.status,
        players: players ?? this.players,
        maxPlayers: maxPlayers,
        isPublic: isPublic,
        roomName: roomName,
        startCash: startCash,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'hostId': hostId,
        'status': status.name,
        'players': players.map((p) => p.toJson()).toList(),
        'maxPlayers': maxPlayers,
        'isPublic': isPublic,
        'roomName': roomName,
        'startCash': startCash,
        'version': version,
        'createdAt': createdAt,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  static Room fromJson(Map<String, dynamic> j) => Room(
        code: j['code'] as String? ?? '',
        hostId: j['hostId'] as String? ?? '',
        status: RoomStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => RoomStatus.lobby,
        ),
        players: ((j['players'] as List?) ?? [])
            .map((e) => RoomPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 6,
        isPublic: j['isPublic'] as bool? ?? false,
        roomName: j['roomName'] as String? ?? '',
        startCash: (j['startCash'] as num?)?.toInt() ?? 1500,
        version: (j['version'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );
}
