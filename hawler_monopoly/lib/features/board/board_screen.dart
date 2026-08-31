import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/widgets.dart';
import '../../data/online/api_client.dart';
import '../../data/online/web_socket_service.dart';
import '../../domain/game_engine.dart';
import '../../domain/models/game_models.dart';
import '../../presentation/game_session_controller.dart';
import '../../presentation/providers.dart';
import '../player/player_info_widget.dart';
import '../cards/chance_card.dart';
import '../property/buy_property_dialog.dart';
import '../trade/trade_dialog.dart';
import '../winner/winner_screen.dart';
import 'board_data.dart';
import 'widgets/board_tile.dart';
import 'widgets/player_token.dart';
import 'widgets/handoff_overlay.dart';
import 'widgets/auction_panel.dart';
import 'widgets/property_management_sheet.dart';
import 'widgets/game_chat_panel.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> with TickerProviderStateMixin {
  late final AnimationController _shake;
  bool _winnerPushed = false;
  bool _cardShown = false;
  bool _wsConnected = true;
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    // Subscribe to WebSocket connection state
    _connSub = WebSocketService.instance.onConnectionState.listen((connected) {
      if (mounted) setState(() => _wsConnected = connected);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameSessionProvider);
    final controller = ref.read(gameSessionProvider.notifier);
    final game = session.game;

    if (game == null) {
      return Scaffold(
        body: LuxuryBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.gold, size: 44),
                const SizedBox(height: 12),
                Text('یاری چالاک نییە', style: AppTextStyles.h3),
              ],
            ),
          ),
        ),
      );
    }

    final isCurHuman = game.currentPlayer?.kind == PlayerKind.human;
    final isMyTurn = session.isOnline
        ? (game.currentPlayer?.id == session.myPlayerId || (ApiClient.instance.currentUserId.isNotEmpty && game.currentPlayer?.id == ApiClient.instance.currentUserId))
        : isCurHuman;

    // دیالۆگی کارت — تەنها بۆ یاریزانی مرۆڤ و لە کاتی ڕیزی خۆی
    if (session.drawnCard != null && !_cardShown && isCurHuman && isMyTurn) {
      _cardShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final card = session.drawnCard!;
        final cur = game.currentPlayer;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => GameCardDialog(
            card: card,
            playerName: cur?.name ?? '',
            onClose: () {
              _cardShown = false;
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              controller.acknowledgeCard();
            },
          ),
        ).whenComplete(() => _cardShown = false);
      });
    }
    if (session.drawnCard == null && _cardShown) _cardShown = false;

    // دیالۆگی کڕین — تەنها بۆ یاریزانی مرۆڤ لە کاتی ڕیزی خۆی
    if (game.phase == GamePhase.propertyDecision &&
        isCurHuman &&
        isMyTurn &&
        !session.showHandoff &&
        !session.busy) {
      _maybeShowBuyDialog(session, game);
    }

    // بردنەوە
    if (game.phase == GamePhase.gameOver && !_winnerPushed) {
      _winnerPushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => WinnerScreen(
              winnerName: game.playerById(game.winnerId)?.name ?? '',
              winnerColor: game.playerById(game.winnerId)?.color ?? AppColors.gold,
              players: game.players,
              netWorths: {for (final p in game.players) p.id: game.netWorth(p.id)},
              round: game.round,
            ),
          ),
          (route) => false,
        );
      });
    }

    final uiTiles = buildBoardTiles();

    // پردی گواستنەوەی Pass & Play — تەختە بە تەواوی دەشاردرێتەوە
    if (session.showHandoff && game.currentPlayer != null) {
      final humans = game.players.where((p) => p.kind == PlayerKind.human && !p.bankrupt).toList();
      final idx = humans.indexWhere((p) => p.id == game.currentPlayer!.id);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: Scaffold(
          body: HandoffOverlay(
            nextPlayer: game.currentPlayer!,
            playerNumber: idx + 1,
            totalHumans: humans.length,
            onConfirm: controller.confirmHandoff,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitDialog(controller);
      },
      child: Scaffold(
        body: LuxuryBackground(
          showCitadel: false,
          child: SafeArea(
            child: Column(
              children: [
                _header(session, game),
                // Reconnect banner when WS is disconnected in online game
                if (session.isOnline && !_wsConnected) const ReconnectBanner(),
                if (game.activeEvent != null) _eventBanner(game.activeEvent!),
                const SizedBox(height: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // تەختەکە بەهێزتر و گەورەتر دەکرێتەوە
                        final boardScale = constraints.maxWidth < 360 ? 0.94 : 0.97;
                        final boardSize = math.min(constraints.maxWidth, constraints.maxHeight) * boardScale;
                        final cell = boardSize / 11;
                        return Center(
                          child: Shake(
                            controller: _shake,
                            child: Container(
                              width: boardSize,
                              height: boardSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                gradient: LinearGradient(
                                  colors: [AppColors.citadelBrown.withValues(alpha: 0.42), AppColors.night2.withValues(alpha: 0.9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 1.2),
                                boxShadow: AppColors.softShadow(blur: 30),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(23),
                                child: Stack(
                                  children: [
                                    CenterScene(
                                      boardSize: boardSize,
                                      boardTheme: ref.watch(profileProvider).value?.equippedBoardTheme ?? 'classic',
                                    ),
                                    for (int i = 0; i < uiTiles.length; i++)
                                      _positionedTile(i, cell, uiTiles[i], game),
                                    ..._playerTokens(game, cell),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (game.phase == GamePhase.auctioning && game.auction != null)
                  AuctionPanel(
                    propertyName: game.board[game.auction!.tileIndex].name,
                    highestBid: game.auction!.highestBid,
                    highestBidder: game.auction!.highestBidderId != null
                        ? game.playerById(game.auction!.highestBidderId!)?.name
                        : null,
                    myCash: game.currentPlayer?.cash ?? 0,
                    canBid: game.currentPlayer?.kind == PlayerKind.human &&
                        !game.auction!.passedBidders.contains(game.currentPlayer!.id),
                    onBid: (v) => controller.bid(v),
                    onPass: () => controller.passBid(),
                  ),
                if (game.pendingTrade != null) ...[
                  if (session.showTradeDialog &&
                      (session.isOnline
                          ? (game.pendingTrade!.toPlayerId == session.myPlayerId ||
                              game.pendingTrade!.toPlayerId == ApiClient.instance.currentUserId)
                          : (game.playerById(game.pendingTrade!.toPlayerId)?.kind == PlayerKind.human)))
                    _TradeAcceptPanel(game: game, controller: controller)
                  else if (game.phase == GamePhase.trading)
                    _TradeWaitingPanel(game: game, controller: controller),
                ],
                const SizedBox(height: 2),
                PlayerInfoBar(
                  players: game.players,
                  activePlayerId: game.currentPlayer?.id,
                  phase: game.phase,
                  onTap: (id) => _showPlayerPanel(id),
                ),
                const SizedBox(height: 10),
                _actionBar(session, game, controller),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _buyDialogShown = false;

  void _maybeShowBuyDialog(GameSession session, GameState game) {
    if (_buyDialogShown || _cardShown) return;
    final cur = game.currentPlayer!;
    final tile = game.board[cur.position];
    if (!tile.isBuyable) return;
    _buyDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _buyDialogShown = false;
        return;
      }
      final price = ref.read(gameSessionProvider.notifier).engine.effectivePrice(game, tile);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => BuyPropertyDialog(
          name: tile.name,
          price: price,
          groupColor: tile.group >= 0
              ? AppColors.propertyGroups[tile.group % AppColors.propertyGroups.length]
              : AppColors.gold,
          cash: cur.cash,
          rent: tile.rentAtLevel(0),
          isStation: tile.isStation,
          onBuy: () {
            _buyDialogShown = false;
            Navigator.of(context, rootNavigator: true).pop();
            ref.read(gameSessionProvider.notifier).decidePurchase(true);
          },
          onDecline: () {
            _buyDialogShown = false;
            Navigator.of(context, rootNavigator: true).pop();
            ref.read(gameSessionProvider.notifier).decidePurchase(false);
          },
        ),
      ).whenComplete(() => _buyDialogShown = false);
    });
  }

  void _showExitDialog(GameSessionController controller) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.night2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('دەرچوون لە یاری؟', style: AppTextStyles.h3),
        content: Text('یارییەکە پاشەکەوت دەکرێت و دەتوانیت دواتر بەردەوام بیت.', style: AppTextStyles.bodySoft),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('مانەوە', style: AppTextStyles.goldLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.leaveToSave();
              Navigator.of(context).pop();
            },
            child: Text('پاشەکەوت و دەرچوون', style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _header(GameSession session, GameState game) {
    final cur = game.currentPlayer;
    final isMyTurn = session.isOnline
        ? (cur?.id == session.myPlayerId || cur?.id == ApiClient.instance.currentUserId)
        : (cur?.kind == PlayerKind.human);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.close, onTap: () => _showExitDialog(ref.read(gameSessionProvider.notifier))),
          const SizedBox(width: 10),
          Expanded(
            child: GlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: cur?.color ?? AppColors.gold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${cur?.name ?? '—'} — ${_phaseName(game.phase)}',
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Turn timer — only in online mode and awaiting roll
                  if (session.isOnline &&
                      isMyTurn &&
                      game.phase == GamePhase.awaitingRoll) ...[
                    const SizedBox(width: 6),
                    TurnTimerWidget(
                      turnStartedAt: game.turnStartedAt,
                      totalSeconds: 30,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.loop_rounded, size: 15, color: AppColors.gold),
                const SizedBox(width: 5),
                Text('دۆرە ${game.round}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Connection indicator (online only)
          if (session.isOnline) ...[
            const SizedBox(width: 8),
            ConnectionDot(connected: _wsConnected),
          ],
          if (!session.isOnline) ...[
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.handshake_rounded,
              onTap: game.phase != GamePhase.trading && game.pendingTrade == null
                  ? () => _openTradeDialog(session, game, ref.read(gameSessionProvider.notifier))
                  : null,
            ),
          ],
          const SizedBox(width: 8),
          CircleIconButton(icon: Icons.chat_bubble_outline, onTap: _openGameChat),
          const SizedBox(width: 8),
          CircleIconButton(icon: Icons.account_balance_wallet, onTap: () => _showMyProperties(session, game)),
        ],
      ),
    );
  }

  String _phaseName(GamePhase p) => switch (p) {
        GamePhase.awaitingRoll => 'ڕیزی بەرد',
        GamePhase.rolling => 'بەرد دەجوڵێت...',
        GamePhase.moving => 'دەڕوات...',
        GamePhase.landing => 'گەیشت',
        GamePhase.propertyDecision => 'بڕیاری کڕین',
        GamePhase.cardEvent => 'کارت',
        GamePhase.auctioning => 'مزایەدە',
        GamePhase.trading => 'بازرگانی',
        GamePhase.payingRent => 'کرێ',
        GamePhase.endTurn => 'کۆتایی ڕیز',
        GamePhase.gameOver => 'کۆتایی یاری',
        _ => '',
      };

  Widget _eventBanner(ActiveGameEvent ev) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amethyst.withValues(alpha: 0.5), AppColors.sapphire.withValues(alpha: 0.4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 18, color: AppColors.goldBright),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${ev.name} — ${ev.description}',
              style: AppTextStyles.caption.copyWith(color: AppColors.ivory, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedTile(int i, double cell, TileData uiTile, GameState game) {
    final (row, col) = _gridPos(i);
    final rotated = (col == 0 || col == 10) && !_isCorner(i);
    final ts = game.tiles[i];
    final def = game.board[i];
    final owner = ts?.ownerId != null ? game.playerById(ts!.ownerId!) : null;
    return Positioned(
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        onTap: () => _showPlayerPanel(ts?.ownerId ?? ''),
        child: BoardTile(
          name: uiTile.name,
          type: uiTile.type,
          groupColor: def.group >= 0 ? AppColors.propertyGroups[def.group % AppColors.propertyGroups.length] : uiTile.groupColor,
          price: def.isBuyable ? def.price : null,
          icon: uiTile.icon,
          owned: ts != null,
          ownerColor: owner?.color,
          level: ts?.level ?? 0,
          mortgaged: ts?.mortgaged ?? false,
          rotated: rotated,
        ),
      ),
    );
  }

  List<Widget> _playerTokens(GameState game, double cell) {
    final byTile = <int, List<Player>>{};
    for (final p in game.players) {
      if (p.bankrupt) continue;
      byTile.putIfAbsent(p.position, () => []).add(p);
    }
    final tokens = <Widget>[];
    byTile.forEach((tileIdx, players) {
      players.asMap().forEach((offset, p) {
        final (row, col) = _gridPos(tileIdx);
        final isActive = game.currentPlayer?.id == p.id;
        final dx = players.length > 1 ? (offset - (players.length - 1) / 2) * cell * 0.22 : 0.0;
        final dy = players.length > 2 ? (offset.isEven ? 0.0 : cell * 0.2) : 0.0;
        tokens.add(
          AnimatedPositioned(
            key: ValueKey(p.id),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            left: col * cell + cell * 0.3 + dx,
            top: row * cell + cell * 0.38 + dy,
            child: PlayerToken(
              color: p.color,
              emoji: p.character.emoji,
              size: cell * 0.42,
              isActive: isActive,
            ),
          ),
        );
      });
    });
    return tokens;
  }

  Widget _actionBar(GameSession session, GameState game, GameSessionController controller) {
    final cur = game.currentPlayer;
    final isMyTurn = session.isOnline
        ? (cur?.id == session.myPlayerId || (ApiClient.instance.currentUserId.isNotEmpty && cur?.id == ApiClient.instance.currentUserId))
        : (cur?.kind == PlayerKind.human);
    final canRoll = isMyTurn &&
        game.phase == GamePhase.awaitingRoll &&
        !session.diceRolling &&
        !session.tokenMoving &&
        !session.busy &&
        !session.showHandoff;
    final canEndTurn = isMyTurn && game.phase == GamePhase.endTurn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.night2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28), width: 1.2),
        boxShadow: AppColors.softShadow(blur: 20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Dice Area (Left)
          _DiceCluster(session: session, game: game),

          const SizedBox(width: 8),

          // 2. Primary Action Button (Center - Expanded)
          Expanded(
            child: session.aiActing
                ? Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.night.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
                        ),
                        SizedBox(width: 8),
                        Text('کۆمپیوتەر بیر دەکاتەوە...', style: TextStyle(fontSize: 11, color: AppColors.ivory)),
                      ],
                    ),
                  )
                : (session.isOnline && !isMyTurn)
                    ? Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.night.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: cur?.color ?? AppColors.gold, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text('ڕیزی ${cur?.name ?? 'یاریزان'}ە...',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldBright)),
                          ],
                        ),
                      )
                    : GoldenButton(
                        label: canEndTurn
                            ? 'کۆتایی ڕیز'
                            : (canRoll
                                ? 'هاویشتنی بەرد'
                                : (cur?.inJail == true && canRoll ? 'هەوڵی دەرچوون' : 'چاوەڕوانی...')),
                        icon: canEndTurn ? Icons.flag_circle_rounded : Icons.casino_rounded,
                        height: 46,
                        fontSize: 13,
                        onTap: canEndTurn
                            ? () {
                                SoundService.instance.vibrateSuccess();
                                SoundService.instance.playMove();
                                controller.endTurn();
                              }
                            : (canRoll
                                ? () {
                                    SoundService.instance.vibrateDice();
                                    SoundService.instance.playDice();
                                    controller.roll();
                                  }
                                : null),
                      ),
          ),

          const SizedBox(width: 8),

          // 3. Quick Action Button (Right)
          if (cur?.inJail == true && isMyTurn && cur!.cash >= GameEngine.bailCost)
            CircleIconButton(
              icon: Icons.lock_open,
              size: 42,
              onTap: controller.payBail,
            )
          else if (isMyTurn && canRoll && !session.isOnline)
            _MultiplierSelector(
              current: game.diceMultiplier,
              energy: game.diceEnergy,
              onSelect: controller.setDiceMultiplier,
            )
          else
            CircleIconButton(
              icon: Icons.chat_bubble_outline,
              size: 42,
              onTap: _openGameChat,
            ),
        ],
      ),
    );
  }

  void _openGameChat() {
    final session = ref.read(gameSessionProvider);
    final game = session.game;
    if (game == null) return;
    final roomId = session.roomCode.isNotEmpty ? session.roomCode : 'local_${game.seed}';
    final profile = ref.read(profileProvider).value;
    final myId = session.myPlayerId.isNotEmpty
        ? session.myPlayerId
        : (ApiClient.instance.currentUserId.isNotEmpty
            ? ApiClient.instance.currentUserId
            : (game.currentPlayer?.id ?? ''));
    final myName = profile?.name ?? (game.currentPlayer?.name ?? 'یاریزان');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GameChatPanel(
        gameRoomId: roomId,
        myId: myId,
        myName: myName,
      ),
    );
  }

  void _openTradeDialog(GameSession session, GameState game, GameSessionController controller) {
    final cur = game.currentPlayer;
    if (cur?.kind != PlayerKind.human) {
      controller.showToast('تەنها لە ڕیزی خۆتدا دەتوانیت بازرگانی بکەیت');
      return;
    }
    showModalBottomSheet<TradeOffer>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TradeDialogSheet(game: game, currentId: cur!.id),
    ).then((offer) {
      if (offer != null) {
        controller.proposeTrade(offer);
      }
    });
  }

  void _showMyProperties(GameSession session, GameState game) {
    final cur = game.currentPlayer;
    if (cur == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PropertyManagementSheet(
        game: game,
        playerId: cur.id,
        canManage: cur.kind == PlayerKind.human,
      ),
    );
  }

  void _showPlayerPanel(String id) {
    final session = ref.read(gameSessionProvider);
    final game = session.game;
    if (game == null) return;
    final p = game.playerById(id);
    if (p == null) return;
    final owned = game.playerProperties(id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          gradient: AppColors.royalBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerToken(color: p.color, emoji: p.character.emoji, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTextStyles.h3),
                      Text('${p.character.name} — ${p.kind == PlayerKind.ai ? 'کۆمپیوتەر' : 'مرۆڤ'}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.cash} 💰', style: AppTextStyles.titleMedium.copyWith(color: AppColors.goldBright)),
                    Text('پێشاندانی سامان: ${game.netWorth(id)}', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('موڵکەکان (${owned.length})', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            if (owned.isEmpty)
              Text('هیچ موڵکێک نییە', style: AppTextStyles.caption)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: owned.map((ts) {
                  final def = game.board[ts.tileIndex];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: def.group >= 0 ? AppColors.propertyGroups[def.group % AppColors.propertyGroups.length].withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      '${def.name}${ts.level > 0 ? ' (${ts.level})' : ''}${ts.mortgaged ? ' 🔒' : ''}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  (int row, int col) _gridPos(int i) {
    if (i <= 10) return (10, 10 - i);
    if (i <= 20) return (10 - (i - 10), 0);
    if (i <= 30) return (0, i - 20);
    return (i - 30, 10);
  }

  bool _isCorner(int i) => i % 10 == 0;
}

/// دوو بەرد لەگەڵ ئەنیمەیشن.
class _DiceCluster extends StatelessWidget {
  final GameSession session;
  final GameState game;
  const _DiceCluster({required this.session, required this.game});

  @override
  Widget build(BuildContext context) {
    final cur = game.currentPlayer;
    final human = cur?.kind == PlayerKind.human;
    final rolling = session.diceRolling;
    final hasEnergy = game.diceEnergy > 0;
    return IgnorePointer(
      ignoring: !human || !session.hasGame,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < game.maxDiceEnergy; i++)
                    Container(
                      width: 5,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: BoxDecoration(
                        color: i < game.diceEnergy ? AppColors.goldBright : AppColors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              Text('ئێرژی: ${game.diceEnergy}', style: AppTextStyles.caption.copyWith(fontSize: 8, color: hasEnergy ? AppColors.gold : AppColors.danger)),
            ],
          ),
          const SizedBox(width: 6),
          _Die(value: game.dice[0], rolling: rolling, highlight: game.dice[0] == game.dice[1]),
          const SizedBox(width: 8),
          _Die(value: game.dice[1], rolling: rolling, highlight: game.dice[0] == game.dice[1]),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                rolling ? '...' : '${game.dice.fold(0, (a, b) => a + b)}',
                style: AppTextStyles.counter.copyWith(fontSize: 20),
              ),
              Text('کۆ', style: AppTextStyles.caption.copyWith(fontSize: 9)),
              if (game.diceMultiplier > 1)
                Text('×${game.diceMultiplier}', style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.goldBright, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

/// ڕیزی داواکاری ئێرژی — x1, x2, x3, x5, x10, x20
class _MultiplierSelector extends StatelessWidget {
  final int current;
  final int energy;
  final ValueChanged<int> onSelect;
  const _MultiplierSelector({required this.current, required this.energy, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const multipliers = [1, 2, 3, 5, 10, 20];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: multipliers.map((m) {
        final selected = m == current;
        final cost = m - 1;
        final canUse = energy >= cost && cost <= energy;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GestureDetector(
            onTap: canUse ? () => onSelect(m) : null,
            child: Container(
              width: 32,
              height: 28,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.goldGradient : null,
                color: selected ? null : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppColors.gold : (canUse ? AppColors.glassBorder : Colors.white.withValues(alpha: 0.08)),
                  width: selected ? 1.5 : 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '×$m',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.night : (canUse ? AppColors.parchment : Colors.white24),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Die extends StatefulWidget {
  final int value;
  final bool rolling;
  final bool highlight;
  const _Die({required this.value, required this.rolling, required this.highlight});

  @override
  State<_Die> createState() => _DieState();
}

class _DieState extends State<_Die> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  int _display = 1;

  @override
  void didUpdateWidget(covariant _Die old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _c.forward(from: 0);
    }
    if (!widget.rolling) _display = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final angle = math.sin(t * math.pi * 6) * (1 - t) * 0.9;
        final bounce = -math.sin(t * math.pi) * 16;
        if (widget.rolling && t > 0.15) _display = ((t * 37) % 6).floor() + 1;
        return Transform.translate(
          offset: Offset(0, bounce),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          gradient: widget.highlight && !widget.rolling ? AppColors.emeraldButton : AppColors.goldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.goldGlow(blur: 16),
          border: Border.all(color: AppColors.ivory.withValues(alpha: 0.6), width: 2),
        ),
        padding: const EdgeInsets.all(9),
        child: _Pips(value: _display),
      ),
    );
  }
}

class _Pips extends StatelessWidget {
  final int value;
  const _Pips({required this.value});

  static const Map<int, List<Alignment>> _layout = {
    1: [Alignment.center],
    2: [Alignment.topRight, Alignment.bottomLeft],
    3: [Alignment.topRight, Alignment.center, Alignment.bottomLeft],
    4: [Alignment.topRight, Alignment.topLeft, Alignment.bottomRight, Alignment.bottomLeft],
    5: [Alignment.topRight, Alignment.topLeft, Alignment.center, Alignment.bottomRight, Alignment.bottomLeft],
    6: [
      Alignment.topRight, Alignment.topLeft,
      Alignment.centerRight, Alignment.centerLeft,
      Alignment.bottomRight, Alignment.bottomLeft,
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pips = _layout[value.clamp(1, 6)]!;
    return Stack(
      children: pips
          .map((a) => Align(
                alignment: a,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.night, shape: BoxShape.circle),
                ),
              ))
          .toList(),
    );
  }
}

/// دیمەنی ناوەندی قەڵا (پارێزراو لە کۆدە کۆنەکەوە بە نوێکردنەوەی ئاسایی).
class CenterScene extends StatefulWidget {
  final double boardSize;
  final String boardTheme;
  const CenterScene({super.key, required this.boardSize, this.boardTheme = 'classic'});

  @override
  State<CenterScene> createState() => _CenterSceneState();
}

class _CenterSceneState extends State<CenterScene> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> get _gradientColors => switch (widget.boardTheme) {
        'night' => const [Color(0x331F5C8B), Color(0xFF0F1A2E), Color(0xFF0D0906)],
        'golden' => const [Color(0x44E8B94A), Color(0xFF3D2A0F), Color(0xFF19110B)],
        'emerald' => const [Color(0x332FBF71), Color(0xFF0F2E22), Color(0xFF0A140F)],
        _ => const [Color(0x3357B3C6), Color(0xFF2A163D), Color(0xFF19110B)],
      };

  @override
  Widget build(BuildContext context) {
    final inner = widget.boardSize * (9 / 11);
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(widget.boardSize / 11),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final float = math.sin(_controller.value * math.pi * 2) * 4;
            final glow = 0.5 + (_controller.value * 0.18);
            return ClipRRect(
              borderRadius: BorderRadius.circular(inner * 0.03),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: _gradientColors,
                    radius: 1.15,
                    center: Alignment.topCenter,
                  ),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.14)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 14 + float * 0.2,
                      left: 18,
                      child: Opacity(
                        opacity: 0.3,
                        child: Icon(Icons.cloud, size: inner * 0.07, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                    Positioned(
                      top: 30 - float * 0.15,
                      right: 26,
                      child: Opacity(
                        opacity: 0.24,
                        child: Icon(Icons.cloud, size: inner * 0.055, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                    Positioned(
                      top: 42 + float * 0.6,
                      left: 42,
                      child: Transform.rotate(
                        angle: -0.08,
                        child: Icon(Icons.flight, size: inner * 0.04, color: AppColors.goldBright.withValues(alpha: 0.55)),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        child: Container(
                          width: inner * 0.4,
                          height: inner * 0.4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                            boxShadow: AppColors.goldGlow(blur: inner * 0.08),
                            border: Border.all(color: AppColors.ivory.withValues(alpha: 0.45), width: 2),
                          ),
                          child: Icon(Icons.castle_rounded, size: inner * 0.2, color: AppColors.night),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: inner * 0.06 + float,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'قەڵای هەولێر',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.ivory,
                                fontWeight: FontWeight.w900,
                                fontSize: inner * 0.055,
                                shadows: [Shadow(color: AppColors.gold.withValues(alpha: 0.5 * glow), blurRadius: 16)],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'شاری زێڕین و یادی کۆن',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.parchment.withValues(alpha: 0.88),
                                letterSpacing: 0.6,
                                fontSize: inner * 0.028,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shake wrapper — لە animate_do بەکارهێنراوە.
class Shake extends StatelessWidget {
  final Widget child;
  final AnimationController controller;
  const Shake({super.key, required this.child, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final offset = math.sin(controller.value * math.pi * 2) * 3.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
    );
  }
}

/// پانێڵی قبوڵکردنی بازرگانی.
class _TradeAcceptPanel extends StatelessWidget {
  final GameState game;
  final GameSessionController controller;
  const _TradeAcceptPanel({required this.game, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = game.pendingTrade!;
    final from = game.playerById(t.fromPlayerId);
    final to = game.playerById(t.toPlayerId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.emerald.withValues(alpha: 0.3), AppColors.night2.withValues(alpha: 0.9)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('پێشنیاری بازرگانی', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text('${from?.name ?? ''} دەیدات بە ${to?.name ?? ''}:', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              if (t.moneyFrom > 0)
                Text('${t.moneyFrom} 💰', style: AppTextStyles.caption.copyWith(color: AppColors.goldBright, fontWeight: FontWeight.w700)),
              ...t.tilesFrom.map((i) => Text('«${game.board[i].name}»', style: AppTextStyles.caption.copyWith(color: AppColors.gold))),
              if (t.moneyTo > 0 || t.tilesTo.isNotEmpty) const Text('⟷', style: TextStyle(color: AppColors.parchment)),
              if (t.moneyTo > 0)
                Text('${t.moneyTo} 💰', style: AppTextStyles.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w700)),
              ...t.tilesTo.map((i) => Text('«${game.board[i].name}»', style: AppTextStyles.caption.copyWith(color: AppColors.info))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GoldenButton(
                  label: 'ڕەتکردنەوە',
                  height: 44,
                  fontSize: 13,
                  variant: ButtonVariant.danger,
                  onTap: () => controller.respondTrade(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoldenButton(
                  label: 'قبوڵکردن',
                  height: 44,
                  fontSize: 13,
                  variant: ButtonVariant.emerald,
                  onTap: () => controller.respondTrade(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// پانێڵی چاوەڕوانی وەڵامی بازرگانی.
class _TradeWaitingPanel extends StatelessWidget {
  final GameState game;
  final GameSessionController controller;
  const _TradeWaitingPanel({required this.game, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = game.pendingTrade!;
    final to = game.playerById(t.toPlayerId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'چاوەڕوانی وەڵامی ${to?.name ?? ''}...',
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: controller.cancelTradeUi,
            icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
