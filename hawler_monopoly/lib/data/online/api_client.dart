import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter API Client — پەیوەستکەری فەرمی ئەپی مۆنۆپۆلی هەولێر بە سێرڤەری Railway.
///
/// Authentication, Game Operations, Real-time Chat, Friends, Leaderboard, Storage.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static String? _baseUrl;
  String? _token;
  String? _currentUserId;
  String? _currentUserName;

  void configure(String baseUrl) {
    _baseUrl = baseUrl;
  }

  String get baseUrl {
    if (_baseUrl != null) return _baseUrl!;
    if (kIsWeb && (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      return 'http://localhost:3000';
    }
    return 'https://backend-production-bdeaa.up.railway.app';
  }
  String? get token => _token;
  String get currentUserId => _currentUserId ?? '';
  String get currentUserName => _currentUserName ?? 'یاریزان';
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// دەرهێنانی لینکی تەواوی وێنەکان (URL Resolution بۆ Uploads).
  String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$baseUrl$cleanPath';
  }

  // ============================================================
  //  Authentication
  // ============================================================

  /// تۆمارکردنی هەژماری نوێ.
  Future<ApiResult<Map<String, dynamic>>> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    final result = await _post('/api/auth/register', {
      'username': username,
      'password': password,
      'displayName': displayName ?? username,
    });
    if (result.ok && result.data != null) {
      _token = result.data!['token'] as String?;
      final user = result.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        _currentUserId = user['id'] as String?;
        _currentUserName = (user['displayName'] ?? user['display_name']) as String?;
      }
      await _saveSession();
    }
    return result;
  }

  /// چوونەژوورەوە بە ناو و وشەی نهێنی.
  Future<ApiResult<Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    final result = await _post('/api/auth/login', {
      'username': username,
      'password': password,
    });
    if (result.ok && result.data != null) {
      _token = result.data!['token'] as String?;
      final user = result.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        _currentUserId = user['id'] as String?;
        _currentUserName = (user['displayName'] ?? user['display_name']) as String?;
      }
      await _saveSession();
    }
    return result;
  }

  /// چوونەژوورەوەی خێرا وەک میوان (Guest Account).
  Future<ApiResult<Map<String, dynamic>>> guestLogin({String? displayName}) async {
    final result = await _post('/api/auth/guest', {
      'displayName': displayName,
    });
    if (result.ok && result.data != null) {
      _token = result.data!['token'] as String?;
      final user = result.data!['user'] as Map<String, dynamic>?;
      if (user != null) {
        _currentUserId = user['id'] as String?;
        _currentUserName = (user['displayName'] ?? user['display_name']) as String?;
      }
      await _saveSession();
    }
    return result;
  }

  /// گەڕاندنەوەی دانیشتنی پێشوو لە کۆگای ناوخۆیی.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    _currentUserId = prefs.getString('api_user_id');
    _currentUserName = prefs.getString('api_user_name');

    if (_token != null) {
      final me = await getProfile();
      if (me.ok && me.data != null) {
        final user = me.data!['user'] as Map<String, dynamic>?;
        if (user != null) {
          _currentUserId = user['id'] as String?;
          _currentUserName = (user['displayName'] ?? user['display_name']) as String?;
          await _saveSession();
        }
        return true;
      }
    }
    return false;
  }

  /// دەرچوون لە هەژمار.
  Future<void> logout() async {
    _token = null;
    _currentUserId = null;
    _currentUserName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('api_user_id');
    await prefs.remove('api_user_name');
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('api_token', _token!);
    if (_currentUserId != null) await prefs.setString('api_user_id', _currentUserId!);
    if (_currentUserName != null) await prefs.setString('api_user_name', _currentUserName!);
  }

  // ============================================================
  //  User / Profile / Storage
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getProfile() async {
    return _get('/api/auth/me');
  }

  Future<ApiResult<Map<String, dynamic>>> updateProfile({String? displayName, String? avatarUrl}) async {
    return _put('/api/users/me', {
      if (displayName != null) 'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> getUserStats() async {
    return _get('/api/users/me/stats');
  }

  /// بارکردنی وێنەی پرۆفایل بۆ Object Storage لە سێرڤەر.
  Future<ApiResult<Map<String, dynamic>>> uploadAvatar(Uint8List bytes, {String mimeType = 'image/png'}) async {
    final base64String = base64Encode(bytes);
    return _post('/api/users/me/avatar', {
      'imageBase64': base64String,
      'mimeType': mimeType,
    });
  }

  // ============================================================
  //  Game Rooms
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> createRoom({
    String? roomName,
    bool isPublic = false,
    int maxPlayers = 6,
    int startCash = 1500,
  }) async {
    return _post('/api/rooms', {
      'roomName': roomName ?? '',
      'isPublic': isPublic,
      'maxPlayers': maxPlayers,
      'startCash': startCash,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> joinRoom(String code) async {
    return _post('/api/rooms/${code.toUpperCase()}/join', {});
  }

  Future<ApiResult<Map<String, dynamic>>> readyRoom(String code, bool ready) async {
    return _post('/api/rooms/${code.toUpperCase()}/ready', {'ready': ready});
  }

  Future<ApiResult<Map<String, dynamic>>> startGame(String code) async {
    return _post('/api/rooms/${code.toUpperCase()}/start', {});
  }

  Future<ApiResult<Map<String, dynamic>>> leaveRoom(String code) async {
    return _post('/api/rooms/${code.toUpperCase()}/leave', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getRoom(String code) async {
    return _get('/api/rooms/${code.toUpperCase()}');
  }

  Future<ApiResult<Map<String, dynamic>>> getPublicRooms() async {
    return _get('/api/rooms/public');
  }

  // ============================================================
  //  Game Actions (Server-Authoritative)
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> rollDice(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/roll', {});
  }

  Future<ApiResult<Map<String, dynamic>>> movePlayer(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/move', {});
  }

  Future<ApiResult<Map<String, dynamic>>> resolveLanding(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/resolve', {});
  }

  Future<ApiResult<Map<String, dynamic>>> buyProperty(String roomCode, int tileIndex, int price) async {
    return _post('/api/games/${roomCode.toUpperCase()}/buy', {
      'tileIndex': tileIndex,
      'price': price,
    });
  }

  /// ڕەتکردنەوەی کڕینی موڵک — دەچێتە مزایەدە.
  ///
  /// پێشتر کڵاینت `end-turn`ی بانگ دەکرد کە سێرڤەر ڕەتی دەکردەوە و
  /// یارییەکە هەڵدەواسرا.
  Future<ApiResult<Map<String, dynamic>>> declinePurchase(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/decline', {});
  }

  Future<ApiResult<Map<String, dynamic>>> upgradeProperty(String roomCode, int tileIndex) async {
    return _post('/api/games/${roomCode.toUpperCase()}/upgrade', {
      'tileIndex': tileIndex,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> endTurn(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/end-turn', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getGameState(String roomCode) async {
    return _get('/api/games/${roomCode.toUpperCase()}/state');
  }

  // ============================================================
  //  Chat (In-Game + Friends + Reactions)
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> sendGameChat(String roomCode, String text, {String? emoji}) async {
    return _post('/api/chat/game/${roomCode.toUpperCase()}', {
      'text': text,
      'emoji': emoji,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> sendGameReaction(String roomCode, String emoji) async {
    return _post('/api/chat/game/${roomCode.toUpperCase()}/reaction', {
      'emoji': emoji,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> getGameChat(String roomCode, {int limit = 100}) async {
    return _get('/api/chat/game/${roomCode.toUpperCase()}?limit=$limit');
  }

  Future<ApiResult<Map<String, dynamic>>> sendFriendChat(String friendId, String text, {String? emoji}) async {
    return _post('/api/chat/friend/$friendId', {
      'text': text,
      'emoji': emoji,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> getFriendChat(String friendId) async {
    return _get('/api/chat/friend/$friendId');
  }

  Future<ApiResult<Map<String, dynamic>>> markFriendChatRead(String friendId) async {
    return _post('/api/chat/friend/$friendId/read', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getUnreadChats() async {
    return _get('/api/chat/unread');
  }

  // ============================================================
  //  Friends
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getFriends() async {
    return _get('/api/friends');
  }

  Future<ApiResult<Map<String, dynamic>>> addFriend(String friendId) async {
    return _post('/api/friends/add/$friendId', {});
  }

  Future<ApiResult<Map<String, dynamic>>> acceptFriend(String friendId) async {
    return _post('/api/friends/accept/$friendId', {});
  }

  Future<ApiResult<Map<String, dynamic>>> removeFriend(String friendId) async {
    return _post('/api/friends/remove/$friendId', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getFriendRequests() async {
    return _get('/api/friends/requests');
  }

  // ============================================================
  //  Auctions & Trading (Server-Authoritative)
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> placeAuctionBid(String roomCode, int amount) async {
    return _post('/api/games/${roomCode.toUpperCase()}/auction/bid', {'amount': amount});
  }

  Future<ApiResult<Map<String, dynamic>>> passAuctionBid(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/auction/pass', {});
  }

  Future<ApiResult<Map<String, dynamic>>> proposeTrade({
    required String roomCode,
    required String toPlayerId,
    int fromMoney = 0,
    int toMoney = 0,
    List<int> fromTiles = const [],
    List<int> toTiles = const [],
  }) async {
    return _post('/api/games/${roomCode.toUpperCase()}/trade/propose', {
      'toPlayerId': toPlayerId,
      'fromMoney': fromMoney,
      'toMoney': toMoney,
      'fromTileIndices': fromTiles,
      'toTileIndices': toTiles,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> respondTrade(String roomCode, bool accept) async {
    return _post('/api/games/${roomCode.toUpperCase()}/trade/respond', {'accept': accept});
  }

  Future<ApiResult<Map<String, dynamic>>> mortgageProperty(String roomCode, int tileIndex) async {
    return _post('/api/games/${roomCode.toUpperCase()}/mortgage', {'tileIndex': tileIndex});
  }

  Future<ApiResult<Map<String, dynamic>>> unmortgageProperty(String roomCode, int tileIndex) async {
    return _post('/api/games/${roomCode.toUpperCase()}/unmortgage', {'tileIndex': tileIndex});
  }

  Future<ApiResult<Map<String, dynamic>>> spectateGame(String roomCode) async {
    return _post('/api/games/${roomCode.toUpperCase()}/spectate', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getGameTransactions(String roomCode) async {
    return _get('/api/games/${roomCode.toUpperCase()}/transactions');
  }

  // ============================================================
  //  Rewards, Missions & Season
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getDailyRewards() async {
    return _get('/api/rewards/daily');
  }

  Future<ApiResult<Map<String, dynamic>>> claimDailyReward(int dayNumber) async {
    return _post('/api/rewards/daily/claim', {'dayNumber': dayNumber});
  }

  Future<ApiResult<Map<String, dynamic>>> getMissions() async {
    return _get('/api/rewards/missions');
  }

  Future<ApiResult<Map<String, dynamic>>> claimMission(String missionId) async {
    return _post('/api/rewards/missions/$missionId/claim', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getSeason() async {
    return _get('/api/rewards/season');
  }

  Future<ApiResult<Map<String, dynamic>>> claimSeasonTier(int tier) async {
    return _post('/api/rewards/season/claim', {'tier': tier});
  }

  // ============================================================
  //  Shop & Inventory
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getShopCatalog() async {
    return _get('/api/shop/catalog');
  }

  Future<ApiResult<Map<String, dynamic>>> getInventory() async {
    return _get('/api/shop/inventory');
  }

  Future<ApiResult<Map<String, dynamic>>> buyCosmetic(String cosmeticId, {String currency = 'coins'}) async {
    return _post('/api/shop/buy', {'cosmeticId': cosmeticId, 'currency': currency});
  }

  Future<ApiResult<Map<String, dynamic>>> equipCosmetic(String cosmeticId) async {
    return _post('/api/shop/equip', {'cosmeticId': cosmeticId});
  }

  // ============================================================
  //  Match History
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getMatchHistory({int page = 1, int limit = 20}) async {
    return _get('/api/matches/history?page=$page&limit=$limit');
  }

  Future<ApiResult<Map<String, dynamic>>> getMatchDetail(int matchId) async {
    return _get('/api/matches/$matchId');
  }

  // ============================================================
  //  Leaderboard
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> getLeaderboard(String period) async {
    return _get('/api/leaderboard/$period');
  }

  // ============================================================
  //  HTTP Helpers
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> _get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } catch (e) {
      return ApiResult(error: 'پەیوەندی نەبەسترا — $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } catch (e) {
      return ApiResult(error: 'پەیوەندی نەبەسترا — $e');
    }
  }

  Future<ApiResult<Map<String, dynamic>>> _put(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _parseResponse(response);
    } catch (e) {
      return ApiResult(error: 'پەیوەندی نەبەسترا — $e');
    }
  }

  ApiResult<Map<String, dynamic>> _parseResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult.ok(data);
      }
      return ApiResult(error: data['error'] as String? ?? 'هەڵەیەک ڕوویدا.');
    } catch (e) {
      return const ApiResult(error: 'وەڵام نادروستە.');
    }
  }
}

/// ئەنجامی داواکارییەکان.
class ApiResult<T> {
  final T? data;
  final String? error;

  const ApiResult({this.data, this.error});

  factory ApiResult.ok(T data) => ApiResult(data: data);

  bool get ok => data != null && error == null;
  bool get isError => error != null;
}
