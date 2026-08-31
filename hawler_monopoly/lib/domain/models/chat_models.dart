library;

/// مۆدێلەکانی گفتوگۆ — جیاوازکردنی گفتوگۆی یاری و گفتوگۆی هاوڕێکان.

/// نامەی گفتوگۆی یاری — نامەیەک لە ناو یارییەکدا.
class GameChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? emoji;
  final int timestamp;
  final String gameRoomId;

  const GameChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.emoji,
    required this.timestamp,
    required this.gameRoomId,
  });

  bool get isEmoji => (emoji != null && emoji!.isNotEmpty) && text.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'emoji': emoji,
    'timestamp': timestamp,
    'gameRoomId': gameRoomId,
  };

  factory GameChatMessage.fromJson(Map<String, dynamic> j) => GameChatMessage(
    id: (j['id'] as String?) ?? '',
    senderId: (j['senderId'] ?? j['sender_id'] as String?) ?? '',
    senderName: (j['senderName'] ?? j['sender_name'] as String?) ?? 'یاریزان',
    text: (j['text'] as String?) ?? '',
    emoji: j['emoji'] as String?,
    timestamp: _parseTimestamp(j['timestamp']),
    gameRoomId: (j['gameRoomId'] ?? j['game_room_id'] as String?) ?? '',
  );

  static int _parseTimestamp(dynamic ts) {
    if (ts is int) return ts < 10000000000 ? ts * 1000 : ts;
    if (ts is num) return (ts < 10000000000 ? ts * 1000 : ts).toInt();
    if (ts is String) {
      final parsed = int.tryParse(ts);
      if (parsed != null) return parsed < 10000000000 ? parsed * 1000 : parsed;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}

/// نامەی گفتوگۆی هاوڕێکان — نامەی تایبەت نێوان دوو کەس.
class FriendMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? emoji;
  final int timestamp;
  final bool read;

  const FriendMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.emoji,
    required this.timestamp,
    this.read = false,
  });

  bool get isEmoji => (emoji != null && emoji!.isNotEmpty) && text.isEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'emoji': emoji,
    'timestamp': timestamp,
    'read': read,
  };

  factory FriendMessage.fromJson(Map<String, dynamic> j) => FriendMessage(
    id: (j['id'] as String?) ?? '',
    senderId: (j['senderId'] ?? j['sender_id'] as String?) ?? '',
    receiverId: (j['receiverId'] ?? j['receiver_id'] as String?) ?? '',
    text: (j['text'] as String?) ?? '',
    emoji: j['emoji'] as String?,
    timestamp: GameChatMessage._parseTimestamp(j['timestamp']),
    read: j['read'] == true || j['read'] == 1,
  );
}

/// واکۆنی ڕەئاکشنی خێرا لە یاری (Quick Reaction).
class QuickReaction {
  final String emoji;
  final String senderId;
  final String senderName;
  final int timestamp;
  final String roomCode;

  const QuickReaction({
    required this.emoji,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.roomCode,
  });

  factory QuickReaction.fromJson(Map<String, dynamic> j) => QuickReaction(
    emoji: (j['emoji'] as String?) ?? '👍',
    senderId: (j['userId'] ?? j['senderId'] ?? j['sender_id'] as String?) ?? '',
    senderName: (j['senderName'] ?? j['sender_name'] as String?) ?? 'یاریزان',
    timestamp: GameChatMessage._parseTimestamp(j['timestamp']),
    roomCode: (j['roomCode'] ?? j['room_code'] as String?) ?? '',
  );
}

/// ئۆنلاین دۆخی هاوڕێ.
enum FriendOnlineStatus { online, offline, inGame }

class FriendProfile {
  final String id;
  final String name;
  final String? avatarUrl;
  final String characterId;
  final int level;
  final FriendOnlineStatus status;
  final int lastSeen;
  final int unreadCount;

  const FriendProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.characterId = 'business',
    this.level = 1,
    this.status = FriendOnlineStatus.offline,
    this.lastSeen = 0,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'characterId': characterId,
    'level': level,
    'status': status.name,
    'lastSeen': lastSeen,
    'unreadCount': unreadCount,
  };

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
    id: (j['id'] ?? j['userId'] ?? j['user_id'] as String?) ?? '',
    name: (j['displayName'] ?? j['display_name'] ?? j['name'] as String?) ?? 'هاوڕێ',
    avatarUrl: j['avatarUrl'] ?? j['avatar_url'] as String?,
    characterId: (j['characterId'] ?? j['character_id'] as String?) ?? 'business',
    level: (j['level'] as num?)?.toInt() ?? 1,
    status: FriendOnlineStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => FriendOnlineStatus.offline,
    ),
    lastSeen: (j['lastSeen'] ?? j['last_seen'] as num?)?.toInt() ?? 0,
    unreadCount: (j['unreadCount'] ?? j['unread_count'] as num?)?.toInt() ?? 0,
  );

  FriendProfile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? characterId,
    int? level,
    FriendOnlineStatus? status,
    int? lastSeen,
    int? unreadCount,
  }) => FriendProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    characterId: characterId ?? this.characterId,
    level: level ?? this.level,
    status: status ?? this.status,
    lastSeen: lastSeen ?? this.lastSeen,
    unreadCount: unreadCount ?? this.unreadCount,
  );
}
