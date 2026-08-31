import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/models/chat_models.dart';
import 'api_client.dart';

/// خزمەتگوزاری WebSocket بۆ پەیوەندی کاتی-ڕاستەقینە لەگەڵ سێرڤەری مۆنۆپۆلی هەولێر.
class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _shouldReconnect = true;
  String? _activeRoomCode;

  final _gameChatController = StreamController<GameChatMessage>.broadcast();
  final _quickReactionController = StreamController<QuickReaction>.broadcast();
  final _friendChatController = StreamController<FriendMessage>.broadcast();
  final _gameStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<GameChatMessage> get onGameChatMessage => _gameChatController.stream;
  Stream<QuickReaction> get onQuickReaction => _quickReactionController.stream;
  Stream<FriendMessage> get onFriendMessage => _friendChatController.stream;
  Stream<Map<String, dynamic>> get onGameStateUpdate => _gameStateController.stream;
  Stream<Map<String, dynamic>> get onRoomUpdated => _roomUpdatedController.stream;
  Stream<Map<String, dynamic>> get onGameStarted => _gameStartedController.stream;
  Stream<bool> get onConnectionState => _connectionStateController.stream;

  bool get isConnected => _isConnected && _channel != null;

  String get _wsUrl {
    final httpUrl = ApiClient.instance.baseUrl;
    final uri = Uri.parse(httpUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final portPart = uri.hasPort ? ':${uri.port}' : '';
    return '$wsScheme://${uri.host}$portPart/ws';
  }

  /// پەیوەستکردنی WebSocket بە سێرڤەر.
  Future<void> connect() async {
    final token = ApiClient.instance.token;
    if (isConnected) {
      if (token != null) {
        send({'type': 'auth', 'token': token});
      }
      return;
    }
    if (_isConnecting) return;
    _isConnecting = true;
    _shouldReconnect = true;

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 10));
      
      _isConnected = true;
      _isConnecting = false;
      _connectionStateController.add(true);

      // Authenticate socket
      if (token != null) {
        send({'type': 'auth', 'token': token});
      }

      // Re-join active room if was in one
      if (_activeRoomCode != null) {
        joinRoom(_activeRoomCode!);
      }

      // Keepalive ping
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (isConnected) {
          send({'type': 'ping'});
        }
      });

      _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (err) => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'game_chat':
          final msgData = data['message'] as Map<String, dynamic>?;
          if (msgData != null) {
            _gameChatController.add(GameChatMessage.fromJson(msgData));
          }
          break;
        case 'quick_reaction':
          _quickReactionController.add(QuickReaction.fromJson(data));
          break;
        case 'friend_chat':
          final msgData = data['message'] as Map<String, dynamic>?;
          if (msgData != null) {
            _friendChatController.add(FriendMessage.fromJson(msgData));
          }
          break;
        case 'game_state_update':
        case 'dice_rolled':
        case 'player_moved':
        case 'landing_resolved':
        case 'property_bought':
        case 'property_upgraded':
        case 'property_mortgaged':
        case 'property_unmortgaged':
        case 'auction_updated':
        case 'trade_updated':
        case 'trade_resolved':
        case 'spectate_joined':
        case 'turn_ended':
        case 'turn_timeout_advance':
          _gameStateController.add(data);
          break;
        case 'room_updated':
        case 'player_joined':
        case 'player_left':
          _roomUpdatedController.add(data);
          break;
        case 'game_started':
          _gameStartedController.add(data);
          break;
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _pingTimer?.cancel();
    _connectionStateController.add(false);

    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        connect();
      });
    }
  }

  void send(Map<String, dynamic> data) {
    if (isConnected) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  void joinRoom(String roomCode) {
    _activeRoomCode = roomCode.toUpperCase();
    send({'type': 'join_room', 'roomCode': _activeRoomCode});
  }

  void leaveRoom() {
    if (_activeRoomCode != null) {
      send({'type': 'leave_room', 'roomCode': _activeRoomCode});
      _activeRoomCode = null;
    }
  }

  void sendGameChat(String roomCode, String text, {String? emoji}) {
    send({
      'type': 'game_chat',
      'roomCode': roomCode.toUpperCase(),
      'text': text,
      'emoji': emoji,
    });
  }

  void sendQuickReaction(String roomCode, String emoji) {
    send({
      'type': 'quick_reaction',
      'roomCode': roomCode.toUpperCase(),
      'emoji': emoji,
    });
  }

  void sendFriendChat(String friendId, String text, {String? emoji}) {
    send({
      'type': 'friend_chat',
      'friendId': friendId,
      'text': text,
      'emoji': emoji,
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStateController.add(false);
  }
}
