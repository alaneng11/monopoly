library;

/// مۆدێلەکانی گفتوگۆ — جیاوازکردنی گفتوگۆی یاری و گفتوگۆی هاوڕێکان.

/// نامەی گفتوگۆی یاری — نامەیەک لە ژێر یارییەکدا.
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

  bool get isEmoji => emoji != null && text.isEmpty;

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
    id: j['id'] as String? ?? '',
    senderId: j['senderId'] as String? ?? '',
    senderName: j['senderName'] as String? ?? '',
    text: j['text'] as String? ?? '',
    emoji: j['emoji'] as String?,
    timestamp: j['timestamp'] as int? ?? 0,
    gameRoomId: j['gameRoomId'] as String? ?? '',
  );
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

  bool get isEmoji => emoji != null && text.isEmpty;

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
    id: j['id'] as String? ?? '',
    senderId: j['senderId'] as String? ?? '',
    receiverId: j['receiverId'] as String? ?? '',
    text: j['text'] as String? ?? '',
    emoji: j['emoji'] as String?,
    timestamp: j['timestamp'] as int? ?? 0,
    read: j['read'] as bool? ?? false,
  );
}

/// واکۆنی ڕەئاکشن — نیشانکردنی هەست لەسەر تۆکنی یاریزان.
class Reaction {
  final String emoji;
  final String senderId;
  final int expiresAt;

  const Reaction({
    required this.emoji,
    required this.senderId,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;
}

/// ئۆنلاین دۆخی هاوڕێ.
enum FriendOnlineStatus { online, offline, inGame }

class FriendProfile {
  final String id;
  final String name;
  final String characterId;
  final int level;
  final FriendOnlineStatus status;
  final int lastSeen;
  final int unreadCount;

  const FriendProfile({
    required this.id,
    required this.name,
    this.characterId = 'business',
    this.level = 1,
    this.status = FriendOnlineStatus.offline,
    this.lastSeen = 0,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'characterId': characterId,
    'level': level,
    'status': status.name,
    'lastSeen': lastSeen,
    'unreadCount': unreadCount,
  };

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    characterId: j['characterId'] as String? ?? 'business',
    level: j['level'] as int? ?? 1,
    status: FriendOnlineStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => FriendOnlineStatus.offline,
    ),
    lastSeen: j['lastSeen'] as int? ?? 0,
    unreadCount: j['unreadCount'] as int? ?? 0,
  );
}
