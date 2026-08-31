import 'dart:async';

import '../../domain/models/chat_models.dart';
import 'api_client.dart';
import 'web_socket_service.dart';

/// ڕیپۆزیتۆری گفتوگۆ — هاوبەشکردنی نامەکان بە بەکارهێنانی سێرڤەری Railway و WebSocket.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  final Map<String, List<GameChatMessage>> _gameMessageCache = {};
  final Map<String, StreamController<List<GameChatMessage>>> _gameMessageControllers = {};

  final Map<String, List<FriendMessage>> _friendMessageCache = {};
  final Map<String, StreamController<List<FriendMessage>>> _friendMessageControllers = {};

  final StreamController<List<FriendProfile>> _friendsController = StreamController.broadcast();
  Timer? _friendsPollTimer;
  bool _initialized = false;

  String get currentUserId => ApiClient.instance.currentUserId;
  String get currentUserName => ApiClient.instance.currentUserName;

  void init() {
    WebSocketService.instance.connect();
    if (_initialized) return;
    _initialized = true;

    // Listen for incoming game messages via WebSocket
    WebSocketService.instance.onGameChatMessage.listen((msg) {
      final room = msg.gameRoomId.toUpperCase();
      _gameMessageCache.putIfAbsent(room, () => []);
      if (!_gameMessageCache[room]!.any((m) => m.id == msg.id)) {
        _gameMessageCache[room]!.add(msg);
        _gameMessageControllers[room]?.add(List.unmodifiable(_gameMessageCache[room]!));
      }
    });

    // Listen for incoming friend messages via WebSocket
    WebSocketService.instance.onFriendMessage.listen((msg) {
      final otherId = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
      _friendMessageCache.putIfAbsent(otherId, () => []);
      if (!_friendMessageCache[otherId]!.any((m) => m.id == msg.id)) {
        _friendMessageCache[otherId]!.add(msg);
        _friendMessageControllers[otherId]?.add(List.unmodifiable(_friendMessageCache[otherId]!));
      }
    });
  }

  // ============================================================
  //  گفتوگۆی یاری — Game Chat
  // ============================================================

  /// ناردنی نامە لە یاریدا.
  Future<void> sendGameMessage(String gameRoomId, String text, {String? emoji}) async {
    final room = gameRoomId.toUpperCase();
    
    // Send via REST
    final result = await ApiClient.instance.sendGameChat(room, text, emoji: emoji);
    if (result.ok && result.data != null) {
      final msgData = result.data!['message'] as Map<String, dynamic>?;
      if (msgData != null) {
        final msg = GameChatMessage.fromJson(msgData);
        _gameMessageCache.putIfAbsent(room, () => []);
        if (!_gameMessageCache[room]!.any((m) => m.id == msg.id)) {
          _gameMessageCache[room]!.add(msg);
          _gameMessageControllers[room]?.add(List.unmodifiable(_gameMessageCache[room]!));
        }
      }
    } else {
      // Fallback via WebSocket
      WebSocketService.instance.sendGameChat(room, text, emoji: emoji);
    }
  }

  /// ناردنی ڕەئاکشنی خێرا لە یاری (Quick Reaction).
  Future<void> sendQuickReaction(String gameRoomId, String emoji) async {
    final room = gameRoomId.toUpperCase();
    WebSocketService.instance.sendQuickReaction(room, emoji);
    await ApiClient.instance.sendGameReaction(room, emoji);
  }

  /// گوێگرتن لە نامەکانی یاری.
  Stream<List<GameChatMessage>> watchGameMessages(String gameRoomId) {
    final room = gameRoomId.toUpperCase();
    final controller = _gameMessageControllers.putIfAbsent(
      room,
      () => StreamController<List<GameChatMessage>>.broadcast(),
    );

    // Initial fetch from backend
    _fetchGameMessages(room);

    return controller.stream;
  }

  Future<void> _fetchGameMessages(String room) async {
    final result = await ApiClient.instance.getGameChat(room);
    if (result.ok && result.data != null) {
      final rawList = (result.data!['messages'] as List?) ?? [];
      final messages = rawList.map((e) => GameChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      _gameMessageCache[room] = messages;
      _gameMessageControllers[room]?.add(List.unmodifiable(messages));
    } else if (_gameMessageCache.containsKey(room)) {
      _gameMessageControllers[room]?.add(List.unmodifiable(_gameMessageCache[room]!));
    }
  }

  /// گوێگرتن لە ڕەئاکشنەکانی خێرا لە یاری.
  Stream<QuickReaction> watchGameReactions(String gameRoomId) {
    final room = gameRoomId.toUpperCase();
    return WebSocketService.instance.onQuickReaction.where((r) => r.roomCode.toUpperCase() == room);
  }

  // ============================================================
  //  گفتوگۆی هاوڕێکان — Friend Chat
  // ============================================================

  /// ناردنی نامە بۆ هاوڕێ.
  Future<void> sendFriendMessage(String receiverId, String text, {String? emoji}) async {
    // Send via REST
    final result = await ApiClient.instance.sendFriendChat(receiverId, text, emoji: emoji);
    if (result.ok && result.data != null) {
      final msgData = result.data!['message'] as Map<String, dynamic>?;
      if (msgData != null) {
        final msg = FriendMessage.fromJson(msgData);
        _friendMessageCache.putIfAbsent(receiverId, () => []);
        if (!_friendMessageCache[receiverId]!.any((m) => m.id == msg.id)) {
          _friendMessageCache[receiverId]!.add(msg);
          _friendMessageControllers[receiverId]?.add(List.unmodifiable(_friendMessageCache[receiverId]!));
        }
      }
    } else {
      // Fallback via WebSocket
      WebSocketService.instance.sendFriendChat(receiverId, text, emoji: emoji);
    }
  }

  /// گوێگرتن لە نامەکانی هاوڕێ.
  Stream<List<FriendMessage>> watchFriendMessages(String friendId) {
    final controller = _friendMessageControllers.putIfAbsent(
      friendId,
      () => StreamController<List<FriendMessage>>.broadcast(),
    );

    // Initial fetch from backend
    _fetchFriendMessages(friendId);

    return controller.stream;
  }

  Future<void> _fetchFriendMessages(String friendId) async {
    final result = await ApiClient.instance.getFriendChat(friendId);
    if (result.ok && result.data != null) {
      final rawList = (result.data!['messages'] as List?) ?? [];
      final messages = rawList.map((e) => FriendMessage.fromJson(e as Map<String, dynamic>)).toList();
      _friendMessageCache[friendId] = messages;
      _friendMessageControllers[friendId]?.add(List.unmodifiable(messages));
    } else if (_friendMessageCache.containsKey(friendId)) {
      _friendMessageControllers[friendId]?.add(List.unmodifiable(_friendMessageCache[friendId]!));
    }
  }

  /// نیشانکردنی هەموو نامەکان وەک خوێندراو.
  Future<void> markFriendMessagesRead(String friendId) async {
    await ApiClient.instance.markFriendChatRead(friendId);
  }

  // ============================================================
  //  هاوڕێکان — Friends
  // ============================================================

  /// لیستی هاوڕێکان.
  Stream<List<FriendProfile>> watchFriends() {
    _refreshFriends();
    _friendsPollTimer?.cancel();
    _friendsPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshFriends());
    return _friendsController.stream;
  }

  Future<void> _refreshFriends() async {
    final result = await ApiClient.instance.getFriends();
    if (result.ok && result.data != null) {
      final rawList = (result.data!['friends'] as List?) ?? [];
      final friends = rawList.map((e) => FriendProfile.fromJson(e as Map<String, dynamic>)).toList();
      _friendsController.add(friends);
    }
  }

  /// زیادکردنی هاوڕێ بە ناسنامە یان ناو.
  Future<ApiResult<Map<String, dynamic>>> addFriend(String friendId) async {
    final result = await ApiClient.instance.addFriend(friendId);
    _refreshFriends();
    return result;
  }

  /// قبوڵکردنی داواکاری هاوڕێیەتی.
  Future<ApiResult<Map<String, dynamic>>> acceptFriend(String friendId) async {
    final result = await ApiClient.instance.acceptFriend(friendId);
    _refreshFriends();
    return result;
  }
}
