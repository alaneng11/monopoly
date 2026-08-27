import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter API Client — connects to the مۆنۆپۆلی هەولێر backend.
///
/// Handles authentication, game operations, chat, friends, and leaderboard.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  /// Backend base URL — loaded from environment or SharedPreferences.
  static String? _baseUrl;
  
  /// JWT token — persisted locally.
  String? _token;

  /// Initialize the client with a base URL.
  void configure(String baseUrl) {
    _baseUrl = baseUrl;
  }

  String get baseUrl => _baseUrl ?? 'https://backend-production-bdeaa.up.railway.app';
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ============================================================
  //  Authentication
  // ============================================================

  /// Register a new account.
  Future<ApiResult<Map<String, dynamic>>> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    return _post('/api/auth/register', {
      'username': username,
      'password': password,
      'displayName': displayName ?? username,
    });
  }

  /// Login with username and password.
  Future<ApiResult<Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    final result = await _post('/api/auth/login', {
      'username': username,
      'password': password,
    });
    if (result.ok && result.data != null) {
      _token = result.data!['token'];
      await _saveToken();
    }
    return result;
  }

  /// Guest login — creates an anonymous account.
  Future<ApiResult<Map<String, dynamic>>> guestLogin({String? displayName}) async {
    final result = await _post('/api/auth/guest', {
      'displayName': displayName,
    });
    if (result.ok && result.data != null) {
      _token = result.data!['token'];
      await _saveToken();
    }
    return result;
  }

  /// Restore saved token from local storage.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    return _token != null;
  }

  /// Logout — clear token.
  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  Future<void> _saveToken() async {
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token', _token!);
    }
  }

  // ============================================================
  //  User / Profile
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
    return _post('/api/rooms/$code/join', {});
  }

  Future<ApiResult<Map<String, dynamic>>> startGame(String code) async {
    return _post('/api/rooms/$code/start', {});
  }

  Future<ApiResult<Map<String, dynamic>>> getPublicRooms() async {
    return _get('/api/rooms/public');
  }

  // ============================================================
  //  Game Actions (Server-Authoritative)
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> rollDice(String roomCode) async {
    return _post('/api/games/$roomCode/roll', {});
  }

  Future<ApiResult<Map<String, dynamic>>> buyProperty(String roomCode, int tileIndex, int price) async {
    return _post('/api/games/$roomCode/buy', {
      'tileIndex': tileIndex,
      'price': price,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> getGameState(String roomCode) async {
    return _get('/api/games/$roomCode/state');
  }

  Future<ApiResult<Map<String, dynamic>>> endTurn(String roomCode) async {
    return _post('/api/games/$roomCode/end-turn', {});
  }

  // ============================================================
  //  Chat
  // ============================================================

  Future<ApiResult<Map<String, dynamic>>> sendGameChat(String roomCode, String text, {String? emoji}) async {
    return _post('/api/chat/game/$roomCode', {
      'text': text,
      'emoji': emoji,
    });
  }

  Future<ApiResult<Map<String, dynamic>>> getGameChat(String roomCode, {int limit = 100}) async {
    return _get('/api/chat/game/$roomCode?limit=$limit');
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

  Future<ApiResult<Map<String, dynamic>>> getFriendRequests() async {
    return _get('/api/friends/requests');
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
      return ApiResult(error: 'کۆپەی نەدرا — $e');
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
      return ApiResult(error: 'کۆپەی نەدرا — $e');
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
      return ApiResult(error: 'کۆپەی نەدرا — $e');
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
      return ApiResult(error: 'وەڵام نادروستە.');
    }
  }
}

/// API result wrapper.
class ApiResult<T> {
  final T? data;
  final String? error;
  
  const ApiResult({this.data, this.error});
  
  factory ApiResult.ok(T data) => ApiResult(data: data);
  
  bool get ok => data != null && error == null;
  bool get isError => error != null;
}
