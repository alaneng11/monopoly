import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/online/firebase_bootstrap.dart';
import '../../domain/models/chat_models.dart';

/// ڕیپۆزیتۆری گفتوگۆ — هاوبەشکردنی نامەکان لە Firebase Firestore.
///
/// جیاوازکردن:
/// - گفتوگۆی یاری: لە ناو یاریدادا — scoped بە gameRoomId
/// - گفتوگۆی هاوڕێکان: نێوان دوو کەس — scoped بە senderId+receiverId
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  static const _gameChatPath = 'game_chat';
  static const _friendChatPath = 'friend_chat';
  static const _friendsPath = 'friends';
  static const _usersPath = 'users';

  Future<void> _ready() async {
    final s = await FirebaseSetup.ensureInitialized();
    if (s != FirebaseSetupStatus.ready) {
      throw Exception('Firebase بەردەست نییە');
    }
  }

  String get currentUserId {
    final u = FirebaseAuth.instance.currentUser;
    return u?.uid ?? '';
  }

  // ============================================================
  //  گفتوگۆی یاری — Game Chat
  // ============================================================

  /// ناردنی نامە لە یاریدا.
  Future<void> sendGameMessage(String gameRoomId, String text, {String? emoji}) async {
    await _ready();
    final db = FirebaseFirestore.instance;
    final msgRef = db.collection(_gameChatPath).doc(gameRoomId).collection('messages').doc();
    final msg = GameChatMessage(
      id: msgRef.id,
      senderId: currentUserId,
      senderName: await _getMyName(),
      text: text,
      emoji: emoji,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      gameRoomId: gameRoomId,
    );
    await msgRef.set(msg.toJson());
  }

  /// گوێگرتن لە نامەکانی یاری.
  Stream<List<GameChatMessage>> watchGameMessages(String gameRoomId) {
    return FirebaseFirestore.instance
        .collection(_gameChatPath)
        .doc(gameRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GameChatMessage.fromJson(d.data()))
            .toList());
  }

  // ============================================================
  //  گفتوگۆی هاوڕێکان — Friend Chat
  // ============================================================

  /// ناردنی نامە بۆ هاوڕێ.
  Future<void> sendFriendMessage(String receiverId, String text, {String? emoji}) async {
    await _ready();
    final db = FirebaseFirestore.instance;
    final chatId = _chatId(currentUserId, receiverId);
    final msgRef = db.collection(_friendChatPath).doc(chatId).collection('messages').doc();
    final msg = FriendMessage(
      id: msgRef.id,
      senderId: currentUserId,
      receiverId: receiverId,
      text: text,
      emoji: emoji,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await msgRef.set(msg.toJson());

    // نوێکردنەوەی ئۆنلاین دۆخی هاوڕێ
    await _updateFriendUnreadCount(receiverId);
  }

  /// گوێگرتن لە نامەکانی هاوڕێ.
  Stream<List<FriendMessage>> watchFriendMessages(String friendId) {
    final chatId = _chatId(currentUserId, friendId);
    return FirebaseFirestore.instance
        .collection(_friendChatPath)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendMessage.fromJson(d.data()))
            .toList());
  }

  /// نیشانکردنی هەموو نامەکان وەک خوێندراو.
  Future<void> markFriendMessagesRead(String friendId) async {
    await _ready();
    final chatId = _chatId(currentUserId, friendId);
    final unread = await FirebaseFirestore.instance
        .collection(_friendChatPath)
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// ژمارەی نامەی نەخوێندراو.
  Stream<int> watchUnreadCount(String friendId) {
    final chatId = _chatId(currentUserId, friendId);
    return FirebaseFirestore.instance
        .collection(_friendChatPath)
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============================================================
  //  هاوڕێکان — Friends
  // ============================================================

  /// لیستی هاوڕێکان.
  Stream<List<FriendProfile>> watchFriends() {
    return FirebaseFirestore.instance
        .collection(_usersPath)
        .doc(currentUserId)
        .collection(_friendsPath)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FriendProfile.fromJson(d.data()))
            .toList());
  }

  /// زیادکردنی هاوڕێ.
  Future<void> addFriend(String friendId) async {
    await _ready();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    
    // زیادکردن لە لیستی من
    final myRef = db.collection(_usersPath).doc(currentUserId).collection(_friendsPath).doc(friendId);
    batch.set(myRef, {
      'id': friendId,
      'name': await _getFriendName(friendId),
      'level': 1,
      'status': 'offline',
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': 0,
    });
    
    // زیادکردن لە لیستی هاوڕێ
    final theirRef = db.collection(_usersPath).doc(friendId).collection(_friendsPath).doc(currentUserId);
    batch.set(theirRef, {
      'id': currentUserId,
      'name': await _getMyName(),
      'level': 1,
      'status': 'online',
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'unreadCount': 0,
    });
    
    await batch.commit();
  }

  // ============================================================
  //  دۆخی ئۆنلاین — Presence
  // ============================================================

  /// نوێکردنەوەی دۆخی ئۆنلاین.
  Future<void> updatePresence(FriendOnlineStatus status) async {
    try {
      await _ready();
      await FirebaseFirestore.instance.collection(_usersPath).doc(currentUserId).set({
        'status': status.name,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ============================================================
  //  یارمەتیدەرەکان
  // ============================================================

  String _chatId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _updateFriendUnreadCount(String friendId) async {
    try {
      final db = FirebaseFirestore.instance;
      await db.collection(_usersPath).doc(friendId).collection(_friendsPath).doc(currentUserId).update({
        'unreadCount': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<String> _getMyName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_usersPath).doc(currentUserId).get();
      return doc.data()?['name'] as String? ?? 'یاریزان';
    } catch (_) {
      return 'یاریزان';
    }
  }

  Future<String> _getFriendName(String friendId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_usersPath).doc(friendId).get();
      return doc.data()?['name'] as String? ?? 'هاوڕێ';
    } catch (_) {
      return 'هاوڕێ';
    }
  }
}
