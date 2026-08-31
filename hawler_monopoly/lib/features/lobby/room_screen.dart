import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/api_client.dart';
import '../../data/online/models/room_models.dart';
import '../../data/online/online_repository.dart';
import '../../data/online/web_socket_service.dart';
import '../../domain/game_engine.dart';
import '../../domain/models/game_models.dart';
import '../../presentation/game_session_controller.dart';
import '../../presentation/providers.dart';
import '../board/widgets/game_chat_panel.dart';

/// شاشەی ژووری چاوەڕوانی (Waiting Room) — بینینی یاریزانەکان، ئامادەبوون، و دەستپێکردنی یاری.
class RoomScreen extends ConsumerStatefulWidget {
  final String roomCode;
  const RoomScreen({super.key, required this.roomCode});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _repo = RoomRepository.instance;
  StreamSubscription<Room>? _roomSub;
  StreamSubscription<Map<String, dynamic>>? _gameStartSub;
  Room? _room;
  bool _busy = false;
  bool _navigated = false;

  int _prevPlayerCount = 0;

  @override
  void initState() {
    super.initState();
    _roomSub = _repo.watchRoom(widget.roomCode).listen((r) {
      if (!mounted) return;
      // Show notification when new player joins
      if (_room != null && r.players.length > _prevPlayerCount) {
        final newPlayer = r.players.lastOrNull;
        if (newPlayer != null && newPlayer.id != ApiClient.instance.currentUserId) {
          InAppNotificationOverlay.show(
            context,
            InAppNotification(
              title: '${newPlayer.name} بەشداربوو! 🎉',
              message: 'یاریزانی نوێ بەشداری ژوورەکەت بووە',
              icon: Icons.person_add_rounded,
              color: AppColors.emerald,
            ),
          );
        }
      }
      _prevPlayerCount = r.players.length;
      setState(() => _room = r);
      if (r.status == RoomStatus.playing) {
        _navigateToGame(r);
      }
    });

    _gameStartSub = WebSocketService.instance.onGameStarted.listen((event) async {
      if ((event['roomCode'] as String?)?.toUpperCase() == widget.roomCode.toUpperCase()) {
        if (!mounted || _navigated) return;
        if (_room != null) {
          _navigateToGame(_room);
        } else {
          final res = await ApiClient.instance.getRoom(widget.roomCode);
          if (res.ok && res.data != null && res.data!['room'] != null) {
            final r = Room.fromJson(res.data!['room'] as Map<String, dynamic>);
            _navigateToGame(r);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _gameStartSub?.cancel();
    super.dispose();
  }

  void _navigateToGame(Room? room) {
    if (room == null || _navigated) return;
    _navigated = true;
    final myId = ApiClient.instance.currentUserId;

    final setups = room.players.map((p) => PlayerSetup(
      id: p.id,
      name: p.name,
      characterId: p.characterId,
      kind: PlayerKind.human,
    )).toList();

    ref.read(gameSessionProvider.notifier).startOnlineGame(
      roomCode: widget.roomCode,
      myPlayerId: myId,
      setups: setups,
    );

    context.go('/game');
  }

  Future<void> _toggleReady() async {
    final myId = ApiClient.instance.currentUserId;
    final me = _room?.players.where((p) => p.id == myId).firstOrNull;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      await _repo.setReady(widget.roomCode, !me.ready);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startGame() async {
    setState(() => _busy = true);
    try {
      await _repo.startGame(widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveRoom() async {
    await _repo.leaveRoom(widget.roomCode);
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _openChat() {
    final profile = ref.read(profileProvider).value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GameChatPanel(
        gameRoomId: widget.roomCode,
        myId: ApiClient.instance.currentUserId,
        myName: profile?.name ?? 'یاریزان',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ApiClient.instance.currentUserId;
    final isHost = _room?.hostId == myId;
    final me = _room?.players.where((p) => p.id == myId).firstOrNull;
    final isReady = me?.ready ?? false;

    return Scaffold(
      body: LuxuryBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleIconButton(icon: Icons.close, onTap: _leaveRoom),
                    const SizedBox(width: 12),
                    Text('ژووری یاری', style: AppTextStyles.h2),
                    const Spacer(),
                    CircleIconButton(icon: Icons.chat_bubble_outline, onTap: _openChat),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ResponsiveCenter(
                    child: Column(
                      children: [
                        FadeInDown(
                          child: GlassContainer(
                            borderRadius: 24,
                            padding: const EdgeInsets.all(20),
                            borderColor: AppColors.gold.withValues(alpha: 0.5),
                            child: Column(
                              children: [
                                Text(_room?.roomName ?? 'مۆنۆپۆلی هەولێر', style: AppTextStyles.h2),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.goldBright, width: 1.5),
                                      ),
                                      child: Text(
                                        widget.roomCode,
                                        style: AppTextStyles.display.copyWith(
                                          fontSize: 28,
                                          letterSpacing: 4,
                                          color: AppColors.goldBright,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    CircleIconButton(
                                      icon: Icons.copy,
                                      size: 44,
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: widget.roomCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('کۆدی ژوور کۆپیکرا 🎉')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'کۆدەکە بنێرە بۆ هاوڕێکانت بۆ بەشداربوون',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.parchment.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        Row(
                          children: [
                            const Icon(Icons.people, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Text('یاریزانەکان (${_room?.players.length ?? 0}/${_room?.maxPlayers ?? 6})', style: AppTextStyles.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_room == null)
                          const Center(child: CircularProgressIndicator(color: AppColors.gold))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _room!.players.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final p = _room!.players[i];
                              final pIsHost = p.id == _room!.hostId;
                              final pIsMe = p.id == myId;

                              return FadeInUp(
                                delay: Duration(milliseconds: i * 60),
                                child: GlassContainer(
                                  borderRadius: 18,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  borderColor: pIsMe ? AppColors.gold.withValues(alpha: 0.5) : AppColors.glassBorder,
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.sapphire.withValues(alpha: 0.5),
                                                  AppColors.night2,
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: pIsMe ? AppColors.gold : AppColors.glassBorder,
                                                width: 1.5,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              TokenCharacter.byId(p.characterId).emoji,
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 11,
                                              height: 11,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: p.connected ? AppColors.success : AppColors.danger,
                                                border: Border.all(color: AppColors.night, width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(p.name, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
                                                if (pIsMe) ...[
                                                  const SizedBox(width: 6),
                                                  Text('(تۆ)', style: AppTextStyles.caption.copyWith(color: AppColors.gold)),
                                                ],
                                                const Spacer(),
                                                Text(
                                                  TokenCharacter.byId(p.characterId).name,
                                                  style: AppTextStyles.caption.copyWith(
                                                    color: AppColors.sand.withValues(alpha: 0.7),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              pIsHost ? '👑 خاوەنی ژوور' : (p.ready ? '✓ ئامادەیە' : 'چاوەڕوانە...'),
                                              style: AppTextStyles.caption.copyWith(
                                                color: pIsHost ? AppColors.goldBright : (p.ready ? AppColors.success : AppColors.parchment.withValues(alpha: 0.6)),
                                                fontSize: 11,
                                                fontWeight: p.ready ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (pIsHost)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                                          ),
                                          child: const Text('میوان', style: TextStyle(color: AppColors.goldBright, fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Icon(
                                          p.ready ? Icons.check_circle : Icons.hourglass_empty,
                                          color: p.ready ? AppColors.success : AppColors.parchment.withValues(alpha: 0.4),
                                          size: 22,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 30),

                        if (isHost) ...[
                          GoldenButton(
                            label: _busy ? 'چاوەڕوانبە...' : 'دەستپێکردنی یاری',
                            height: 56,
                            icon: Icons.play_arrow_rounded,
                            onTap: (_busy || (_room?.players.length ?? 0) < 2) ? null : _startGame,
                          ),
                          const SizedBox(height: 10),
                          if ((_room?.players.length ?? 0) < 2)
                            Text(
                              'لانی کەم ٢ یاریزان پێویستە بۆ دەستپێکردن',
                              style: AppTextStyles.caption.copyWith(color: AppColors.gold),
                            ),
                        ] else ...[
                          GoldenButton(
                            label: _busy ? '...' : (isReady ? 'هەڵوەشاندنەوەی ئامادەیی' : 'من ئامادەم!'),
                            height: 56,
                            icon: isReady ? Icons.close : Icons.check,
                            onTap: _busy ? null : _toggleReady,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
