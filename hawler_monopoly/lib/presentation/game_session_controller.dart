import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game/hawler_board.dart';
import '../../data/local/persistence.dart';
import '../../domain/ai_brain.dart';
import '../../domain/game_engine.dart';
import '../../domain/models/game_models.dart';
import 'providers.dart';

enum GameMode { local, onlineHost, onlineClient }

/// ڕوکاری دۆخی ڕوونکردنەوە بۆ UI — هەموو پێویستییەکانی بینین.
class GameSession {
  final GameState? game;
  final GameMode mode;
  final bool diceRolling;
  final bool tokenMoving;
  final bool busy;
  final GameCard? drawnCard;
  final bool showHandoff;
  final String? handoffPlayerId;
  final String handoffDismissedFor;
  final String? error;
  final String? toast;
  final bool aiActing;
  final int moveSteps;
  final bool showTradeDialog;
  final TradeOffer? incomingTrade;

  const GameSession({
    this.game,
    this.mode = GameMode.local,
    this.diceRolling = false,
    this.tokenMoving = false,
    this.busy = false,
    this.drawnCard,
    this.showHandoff = false,
    this.handoffPlayerId,
    this.handoffDismissedFor = '',
    this.error,
    this.toast,
    this.aiActing = false,
    this.moveSteps = 0,
    this.showTradeDialog = false,
    this.incomingTrade,
  });

  bool get hasGame => game != null;
  Player? get currentPlayer => game?.currentPlayer;
  bool get gameOver => game?.phase == GamePhase.gameOver;

  GameSession copyWith({
    GameState? game,
    GameMode? mode,
    bool? diceRolling,
    bool? tokenMoving,
    bool? busy,
    GameCard? drawnCard,
    bool clearCard = false,
    bool? showHandoff,
    String? handoffPlayerId,
    String? handoffDismissedFor,
    String? error,
    bool clearError = false,
    String? toast,
    bool clearToast = false,
    bool? aiActing,
    int? moveSteps,
    bool? showTradeDialog,
    TradeOffer? incomingTrade,
    bool clearTrade = false,
  }) =>
      GameSession(
        game: game ?? this.game,
        mode: mode ?? this.mode,
        diceRolling: diceRolling ?? this.diceRolling,
        tokenMoving: tokenMoving ?? this.tokenMoving,
        busy: busy ?? this.busy,
        drawnCard: clearCard ? null : (drawnCard ?? this.drawnCard),
        showHandoff: showHandoff ?? this.showHandoff,
        handoffPlayerId: handoffPlayerId ?? this.handoffPlayerId,
        handoffDismissedFor: handoffDismissedFor ?? this.handoffDismissedFor,
        error: clearError ? null : (error ?? this.error),
        toast: clearToast ? null : (toast ?? this.toast),
        aiActing: aiActing ?? this.aiActing,
        moveSteps: moveSteps ?? this.moveSteps,
        showTradeDialog: showTradeDialog ?? this.showTradeDialog,
        incomingTrade: clearTrade ? null : (incomingTrade ?? this.incomingTrade),
      );
}

final gameSessionProvider = NotifierProvider<GameSessionController, GameSession>(GameSessionController.new);

/// کۆنترۆڵەری ڕوونکردنەوە — لێخوڕینی ئەندازە + AI + Pass&Play.
class GameSessionController extends Notifier<GameSession> {
  final GameEngine engine = GameEngine();
  final AiBrain brain = AiBrain();
  bool _active = true;
  Timer? _aiTimer;
  GameCard? _pendingCard;
  int _totalTrades = 0;
  int _totalAuctionsWon = 0;
  int _totalDiceRolled = 0;
  int _moneyEarned = 0;
  final DateTime _gameStartTime = DateTime.now();

  @override
  GameSession build() {
    _active = true;
    ref.onDispose(() {
      _active = false;
      _aiTimer?.cancel();
    });
    return const GameSession();
  }

  // ------------------------------------------------------------------
  // دەستپێکردن
  // ------------------------------------------------------------------

  void createLocalGame(List<PlayerSetup> setups, {bool saveAndExitAllowed = true}) {
    final result = engine.createGame(board: HawlerBoard.build(), setups: setups);
    _apply(result);
    if (!result.isOk) return;
    // دەستپێکردنی ئێرژی و یارمەتیدەرەکان
    var s = result.state!;
    s = s.copyWith(
      diceEnergy: s.maxDiceEnergy,
      diceMultiplier: 1,
      maxDiceEnergy: 10,
      energyRegenRate: 1,
    );
    state = state.copyWith(game: s);
    LocalPersistence.saveGame(s);
    _maybeRunAi();
    _maybeHandoff(s, null);
  }

  bool get hasLocalSetup => state.hasGame && state.mode == GameMode.local;

  Future<void> tryResumeSavedGame() async {
    final j = await LocalPersistence.loadGame();
    if (j == null) return;
    var s = LocalPersistence.deserialize(j, HawlerBoard.build());
    // پاراستن لە دۆخە نێوەندەکان — گەڕانەوە بۆ دۆخی پارێزراو
    const safePhases = [GamePhase.awaitingRoll, GamePhase.endTurn, GamePhase.gameOver];
    if (!safePhases.contains(s.phase)) {
      s = s.copyWith(phase: GamePhase.endTurn);
    }
    if (s.phase == GamePhase.gameOver) {
      await LocalPersistence.clearGame();
      return;
    }
    state = state.copyWith(game: s, mode: GameMode.local, showHandoff: false);
    _maybeHandoff(s, null);
    _maybeRunAi();
  }

  // ------------------------------------------------------------------
  // یارمەتیدەرەکان
  // ------------------------------------------------------------------

  void _apply(GameResult<GameState> result) {
    if (result.isOk) {
      final g = result.state!;
      state = state.copyWith(game: g, clearError: true);
    } else if (result.isError) {
      state = state.copyWith(error: result.error!.messageKu);
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  void showToast(String msg) {
    state = state.copyWith(toast: msg);
    Timer(const Duration(seconds: 2), () {
      if (_active) state = state.copyWith(clearToast: true);
    });
  }

  bool _isAi(Player? p) => p != null && p.isAi && !p.bankrupt;

  List<String> get humanIds => state.game?.players.where((p) => p.kind == PlayerKind.human && !p.bankrupt).map((p) => p.id).toList() ?? [];

  /// Pass & Play: ئایا پێویستە پردی گواستنەوە پیشان بدرێت؟
  bool _needsHandoff(GameState g) {
    if (state.mode != GameMode.local) return false;
    final humans = g.players.where((p) => p.kind == PlayerKind.human && !p.bankrupt).length;
    return humans >= 2;
  }

  void _maybeHandoff(GameState g, String? previousPlayerId) {
    if (!_needsHandoff(g)) return;
    final cur = g.currentPlayer;
    if (cur == null || cur.bankrupt || _isAi(cur)) return;
    if (g.phase == GamePhase.gameOver) return;
    if (previousPlayerId != null && previousPlayerId == cur.id) return;
    state = state.copyWith(showHandoff: true, handoffPlayerId: cur.id);
  }

  void confirmHandoff() {
    final id = state.handoffPlayerId ?? '';
    state = state.copyWith(showHandoff: false, handoffDismissedFor: id);
  }

  // ------------------------------------------------------------------
  // سووڕ (Turn)
  // ------------------------------------------------------------------

  Future<void> roll() async {
    if (state.busy || !state.hasGame) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (cur == null || state.diceRolling || state.tokenMoving) return;
    if (_isAi(cur)) return;
    if (_needsHandoff(g) && state.showHandoff) return;

    GameResult<GameState> r;
    if (cur.inJail) {
      state = state.copyWith(busy: true, diceRolling: true);
      await Future.delayed(const Duration(milliseconds: 900));
      r = engine.jailTurn(g, cur.id);
    } else {
      state = state.copyWith(busy: true, diceRolling: true);
      await Future.delayed(const Duration(milliseconds: 900));
      r = engine.rollDice(g, cur.id);
    }
    if (!r.isOk) {
      state = state.copyWith(busy: false, diceRolling: false, error: r.error!.messageKu);
      return;
    }
    final g2 = r.state!;
    // گەڕانەوەی مولتیپلایەر بۆ ١ دوای هەر داودانێک
    state = state.copyWith(game: g2.copyWith(diceMultiplier: 1), diceRolling: false, clearError: true);
    // تۆماری چالێنژە: ژمارەی داودان
    _totalDiceRolled++;
    try {
      ref.read(challengeProvider.notifier).incrementProgress('roll_5');
    } catch (_) {}

    if (g2.phase == GamePhase.rolling) {
      await _animateMove(g2, cur.id);
    } else if (g2.phase == GamePhase.endTurn) {
      await _finish(g2, cur.id);
    } else if (g2.phase == GamePhase.gameOver) {
      await _onGameOver(g2);
    }
  }

  Future<void> _animateMove(GameState g, String playerId) async {
    final totalSteps = g.dice.fold<int>(0, (a, b) => a + b);
    state = state.copyWith(tokenMoving: true, busy: true, moveSteps: totalSteps);
    
    // جوڵان قۆنگ بە قۆنگ — هەر قۆنگێک ئاستی تەختە نوێ دەکاتەوە
    final boardLen = g.board.length;
    var currentPos = g.playerById(playerId)!.position;
    
    for (var step = 0; step < totalSteps; step++) {
      if (!_active) return;
      currentPos = (currentPos + 1) % boardLen;
      // نوێکردنەوەی شوێنی یاریزان بۆ هەر قۆنگ
      final players = g.players.map((p) => 
        p.id == playerId ? p.copyWith(position: currentPos) : p
      ).toList();
      final intermediate = g.copyWith(players: players);
      state = state.copyWith(game: intermediate);
      // سووڕاندن — هەر قۆنگ ٢٥٠ms
      await Future.delayed(const Duration(milliseconds: 250));
    }
    
    if (!_active) return;
    // ئەنجامی ڕاستەقینە — جوڵان لە ئەنجامی بەرد
    final r = engine.movePlayer(g, playerId);
    if (!r.isOk) {
      state = state.copyWith(tokenMoving: false, busy: false, error: r.error!.messageKu);
      return;
    }
    final g2 = r.state!;
    state = state.copyWith(game: g2, tokenMoving: false);
    await _resolveLanding(g2, playerId);
  }

  Future<void> _resolveLanding(GameState g, String playerId) async {
    final r = engine.resolveLanding(g, playerId);
    _apply(r);
    if (!r.isOk) return;
    final g2 = r.state!;
    await _dispatchPhase(g2, playerId);
  }

  Future<void> _dispatchPhase(GameState g, String playerId) async {
    final cur = g.playerById(playerId);
    switch (g.phase) {
      case GamePhase.propertyDecision:
        if (_isAi(cur)) {
          await _aiPropertyDecision(g, cur!);
        } else {
          // UI پیشاندانی دیالۆگ لە بینەردا دەکات
          state = state.copyWith(busy: false);
        }
      case GamePhase.cardEvent:
        await _drawCard(g, playerId);
      case GamePhase.endTurn:
        state = state.copyWith(busy: false);
      case GamePhase.auctioning:
        state = state.copyWith(busy: false);
      case GamePhase.gameOver:
        await _onGameOver(g);
      default:
        state = state.copyWith(busy: false);
    }
  }

  Future<void> _drawCard(GameState g, String playerId) async {
    final idx = g.currentPlayer!.position;
    final def = g.board[idx];
    final isEvent = def.type == TileType.event;
    final deck = isEvent ? EventDeck.cards : ChanceDeck.cards;
    final used = isEvent ? engine.usedEventIds : engine.usedChanceIds;
    final available = deck.where((c) => !used.contains(c.id)).toList();
    final card = available.isEmpty ? deck.first : available[math.Random().nextInt(available.length)];
    _pendingCard = card;
    state = state.copyWith(drawnCard: card, busy: false);
  }

  void acknowledgeCard() {
    if (!state.hasGame) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (cur == null) return;
    final card = _pendingCard;
    _pendingCard = null;
    state = state.copyWith(clearCard: true, busy: true);
    final r = engine.drawCard(g, cur.id, forcedCard: card);
    if (!r.isOk) {
      state = state.copyWith(busy: false, error: r.error!.messageKu);
      return;
    }
    final g2 = r.state!;
    state = state.copyWith(game: g2, clearToast: true);
    _afterCard(g2, cur.id);
  }

  Future<void> _afterCard(GameState g, String playerId) async {
    if (g.phase == GamePhase.landing) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _resolveLanding(g, playerId);
    } else if (g.phase == GamePhase.endTurn) {
      state = state.copyWith(busy: false);
    } else if (g.phase == GamePhase.gameOver) {
      await _onGameOver(g);
    } else {
      state = state.copyWith(busy: false);
    }
  }

  // ------------------------------------------------------------------
  // بڕیاری کڕین و مزایەدە
  // ------------------------------------------------------------------

  Future<void> decidePurchase(bool buyIt) async {
    if (!state.hasGame || state.busy) return;
    final g = state.game!;
    if (g.phase != GamePhase.propertyDecision) return;
    final cur = g.currentPlayer!;
    if (_isAi(cur)) return;
    state = state.copyWith(busy: true);
    final tileIndex = cur.position;
    final r = buyIt ? engine.buyTile(g, cur.id) : engine.declinePurchase(g, cur.id);
    _apply(r);
    if (!r.isOk) {
      state = state.copyWith(busy: false);
      return;
    }
    if (buyIt && tileIndex == 39) {
      await ref.read(achievementsProvider.notifier).unlock('landmark');
    }
    // تۆماری چالێنژە: کڕین
    if (buyIt) {
      try {
        ref.read(challengeProvider.notifier).incrementProgress('buy_3');
      } catch (_) {}
    }
    final g2 = r.state!;
    if (g2.phase == GamePhase.auctioning) {
      state = state.copyWith(busy: false);
      _scheduleAuctionAi(g2);
    } else {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> bid(int amount) async {
    if (!state.hasGame || state.busy) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (cur == null || _isAi(cur)) return;
    final r = engine.placeBid(g, cur.id, amount);
    if (!r.isOk) {
      showToast(r.error!.messageKu);
      return;
    }
    state = state.copyWith(game: r.state);
    if (r.state!.phase == GamePhase.auctioning) {
      _scheduleAuctionAi(r.state!);
    } else {
      _afterAuctionClosed(r.state!);
    }
  }

  void passBid() {
    if (!state.hasGame) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (cur == null || _isAi(cur)) return;
    final r = engine.passAuction(g, cur.id);
    if (!r.isOk) {
      showToast(r.error!.messageKu);
      return;
    }
    state = state.copyWith(game: r.state);
    if (r.state!.phase == GamePhase.auctioning) {
      _scheduleAuctionAi(r.state!);
    } else {
      _afterAuctionClosed(r.state!);
    }
  }

  void _afterAuctionClosed(GameState g) {
    final cur = g.currentPlayer;
    if (cur == null) return;
    if (cur.isAi) {
      _finish(g, cur.id);
    }
  }

  void endAuction() {
    if (!state.hasGame) return;
    final r = engine.closeAuction(state.game!);
    _apply(r);
  }

  void _scheduleAuctionAi(GameState g) {
    final a = g.auction;
    if (a == null) return;
    final aiBidders = g.players.where((p) => _isAi(p) && !a.passedBidders.contains(p.id)).toList();
    if (aiBidders.isEmpty) return;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!_active || !state.hasGame) return;
      final g2 = state.game!;
      final a2 = g2.auction;
      if (a2 == null) return;
      final ai = aiBidders.firstWhere((p) => !a2.passedBidders.contains(p.id), orElse: () => aiBidders.first);
      final bid = brain.bidAmount(g2, ai, a2);
      final r = bid < 0 ? engine.passAuction(g2, ai.id) : engine.placeBid(g2, ai.id, bid);
      if (r.isOk) {
        state = state.copyWith(game: r.state);
        if (r.state!.phase == GamePhase.auctioning) {
          _scheduleAuctionAi(r.state!);
        } else {
          // مزایەدە تەواوبوو — بەردەوامبوونی سووڕی یاریزانی چالاک
          final cur = r.state!.currentPlayer!;
          if (cur.isAi) {
            await _finish(r.state!, cur.id);
          }
        }
      }
    });
  }

  // ------------------------------------------------------------------
  // بازرگانی
  // ------------------------------------------------------------------

  void proposeTrade(TradeOffer offer) {
    if (!state.hasGame) return;
    final r = engine.proposeTrade(state.game!, offer);
    _apply(r);
    if (r.isOk) {
      final target = r.state!.playerById(offer.toPlayerId);
      final isAiTarget = target?.isAi ?? false;
      state = state.copyWith(showTradeDialog: !isAiTarget, incomingTrade: r.state!.pendingTrade);
      if (!isAiTarget) {
        // مرۆڤ — خاوەنی ڕیز تەنها دەتوانێت چاوەڕوان بێت
      } else {
        _scheduleTradeAiResponse(r.state!);
      }
    }
  }

  void respondTrade(bool accept) {
    if (!state.hasGame) return;
    final t = state.game!.pendingTrade;
    if (t == null) return;
    final cur = state.game!.currentPlayer!;
    final responder = t.acceptedByFrom ? t.toPlayerId : cur.id;
    _respondTradeInternal(responder, accept);
  }

  Future<void> _respondTradeInternal(String responder, bool accept) async {
    if (!state.hasGame) return;
    final t = state.game!.pendingTrade;
    if (t == null) return;
    final r = engine.respondToTrade(state.game!, responder, accept);
    _apply(r);
    if (r.isOk && r.state!.pendingTrade == null && accept) {
      await ref.read(achievementsProvider.notifier).unlock('trader');
      _totalTrades++;
      try {
        ref.read(challengeProvider.notifier).incrementProgress('trade_1');
        ref.read(challengeProvider.notifier).incrementProgress('complete_set');
      } catch (_) {}
    }
    state = state.copyWith(showTradeDialog: false, clearTrade: true, aiActing: false);
  }

  void cancelTradeUi() {
    // ڕەتکردنەوەی بازرگانی چالاک — قۆناغ دەگەڕێتەوە بۆ کۆتایی سووڕ
    if (state.hasGame && state.game!.pendingTrade != null) {
      final t = state.game!.pendingTrade!;
      final r = engine.respondToTrade(state.game!, t.toPlayerId, false);
      _apply(r);
    }
    state = state.copyWith(showTradeDialog: false, clearTrade: true, aiActing: false);
  }

  void _scheduleTradeAiResponse(GameState g) {
    final t = g.pendingTrade;
    if (t == null) return;
    final target = g.playerById(t.toPlayerId);
    if (target == null || !_isAi(target)) return;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!_active || !state.hasGame) return;
      final g2 = state.game!;
      final t2 = g2.pendingTrade;
      if (t2 == null) return;
      final accept = brain.acceptTrade(g2, t2, target);
      final r = engine.respondToTrade(g2, t2.toPlayerId, accept);
      _apply(r);
      state = state.copyWith(showTradeDialog: false, clearTrade: true, aiActing: false);
    });
  }

  // ------------------------------------------------------------------
  // موڵکەکان
  // ------------------------------------------------------------------

  void upgradeTile(int tileIndex) {
    if (!state.hasGame) return;
    final g = state.game!;
    final r = engine.upgradeTile(g, g.currentPlayer!.id, tileIndex);
    _apply(r);
    if (r.isOk) {
      try {
        ref.read(challengeProvider.notifier).incrementProgress('upgrade_2');
        ref.read(challengeProvider.notifier).incrementProgress('upgrade_5');
      } catch (_) {}
    }
  }

  void mortgageTile(int tileIndex) {
    if (!state.hasGame) return;
    final r = engine.mortgageTile(state.game!, state.game!.currentPlayer!.id, tileIndex);
    _apply(r);
  }

  void unmortgageTile(int tileIndex) {
    if (!state.hasGame) return;
    final r = engine.unmortgageTile(state.game!, state.game!.currentPlayer!.id, tileIndex);
    _apply(r);
  }

  void sellTile(int tileIndex) {
    if (!state.hasGame) return;
    final r = engine.sellTile(state.game!, state.game!.currentPlayer!.id, tileIndex);
    _apply(r);
  }

  void payBail() {
    if (!state.hasGame) return;
    final cur = state.game!.currentPlayer!;
    final r = engine.payBail(state.game!, cur.id);
    _apply(r);
    if (r.isOk) {
      final g2 = r.state!;
      Timer(const Duration(milliseconds: 600), () => _continueAfterJail(g2, cur.id));
    }
  }

  /// گۆڕینی داواکاری بۆ ئێرژی بەرزکردنەوە
  void setDiceMultiplier(int multiplier) {
    if (!state.hasGame) return;
    final g = state.game!;
    // بەرزکردنەوەی ئێرژی = کەمکردنەوەی ئێرژی
    final energyCost = multiplier - 1;
    if (g.diceEnergy < energyCost) {
      showToast('ئێرژی بەس نییە بۆ ×$multiplier');
      return;
    }
    state = state.copyWith(game: g.copyWith(
      diceMultiplier: multiplier,
      diceEnergy: g.diceEnergy - energyCost,
    ));
  }

  Future<void> _continueAfterJail(GameState g, String playerId) async {
    if (!_active) return;
    final r = engine.movePlayer(g.copyWith(phase: GamePhase.rolling), playerId);
    if (!r.isOk) {
      _apply(r);
      return;
    }
    await _animateMove(r.state!, playerId);
  }

  // ------------------------------------------------------------------
  // کۆتایی سووڕ
  // ------------------------------------------------------------------

  Future<void> endTurn() async {
    if (!state.hasGame || state.busy) return;
    final g = state.game!;
    if (g.phase == GamePhase.gameOver) return;
    final prevId = g.currentPlayer?.id;
    if (g.phase != GamePhase.endTurn) {
      // ڕێگەدان بە کۆتایی له قۆناغی بڕیار/کارتدا بەبێ بڕیار
      showToast('سەرەتا بڕیاری ئەم قۆناغە بدە');
      return;
    }
    state = state.copyWith(busy: true);
    final r = engine.finishRound(g, prevId!);
    _apply(r);
    if (!r.isOk) {
      state = state.copyWith(busy: false);
      return;
    }
    final g2 = r.state!;
    await LocalPersistence.saveGame(g2);
    if (g2.phase == GamePhase.gameOver) {
      await _onGameOver(g2);
      return;
    }
    state = state.copyWith(busy: false);
    _maybeHandoff(g2, prevId);
    _maybeRunAi();
  }

  // ------------------------------------------------------------------
  // AI
  // ------------------------------------------------------------------

  void _maybeRunAi() {
    if (!state.hasGame) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (!_isAi(cur)) return;
    if (g.phase == GamePhase.gameOver) return;
    state = state.copyWith(aiActing: true);
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 1100), () {
      if (_active) _runAiStep();
    });
  }

  Future<void> _runAiStep() async {
    if (!_active || !state.hasGame) return;
    final g = state.game!;
    final cur = g.currentPlayer;
    if (cur == null || !_isAi(cur)) {
      state = state.copyWith(aiActing: false);
      return;
    }

    switch (g.phase) {
      case GamePhase.awaitingRoll:
        GameResult<GameState> r;
        if (cur.inJail) {
          if (brain.payBail(g, cur) && cur.cash >= GameEngine.bailCost && cur.jailTurns < 1) {
            r = engine.payBail(g, cur.id);
            if (r.isOk) {
              final g2 = r.state!;
              state = state.copyWith(game: g2, diceRolling: true);
              await Future.delayed(const Duration(milliseconds: 700));
              final rm = engine.movePlayer(g2.copyWith(phase: GamePhase.rolling), cur.id);
              if (rm.isOk) {
                state = state.copyWith(game: rm.state, diceRolling: false, tokenMoving: true);
                await Future.delayed(const Duration(milliseconds: 600));
                await _resolveLanding(rm.state!, cur.id);
              } else {
                _apply(rm);
              }
              return;
            }
          }
          state = state.copyWith(diceRolling: true);
          await Future.delayed(const Duration(milliseconds: 700));
          r = engine.jailTurn(g, cur.id);
        } else {
          state = state.copyWith(diceRolling: true);
          await Future.delayed(const Duration(milliseconds: 700));
          r = engine.rollDice(g, cur.id);
        }
        if (!_active) return;
        if (!r.isOk) {
          state = state.copyWith(diceRolling: false, aiActing: false);
          return;
        }
        final g2 = r.state!;
        state = state.copyWith(game: g2, diceRolling: false);
        if (g2.phase == GamePhase.rolling) {
          await _animateMove(g2, cur.id);
        } else if (g2.phase == GamePhase.endTurn) {
          await _finish(g2, cur.id);
        }
      case GamePhase.propertyDecision:
        await _aiPropertyDecision(g, cur);
      case GamePhase.cardEvent:
        final idx = cur.position;
        final def = g.board[idx];
        final isEvent = def.type == TileType.event;
        final deck = isEvent ? EventDeck.cards : ChanceDeck.cards;
        final used = isEvent ? engine.usedEventIds : engine.usedChanceIds;
        final available = deck.where((c) => !used.contains(c.id)).toList();
        final card = available.isEmpty ? deck.first : available.first;
        _pendingCard = card;
        state = state.copyWith(drawnCard: card);
        await Future.delayed(const Duration(milliseconds: 1400));
        acknowledgeCard();
      case GamePhase.auctioning:
        _scheduleAuctionAi(g);
        state = state.copyWith(aiActing: false);
      case GamePhase.endTurn:
        await _finish(g, cur.id);
      case GamePhase.gameOver:
        await _onGameOver(g);
      default:
        state = state.copyWith(aiActing: false);
    }
  }

  Future<void> _aiPropertyDecision(GameState g, Player ai) async {
    final def = g.board[ai.position];
    final buy = brain.shouldBuy(g, ai, def);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_active || !state.hasGame) return;
    final g2 = state.game!;
    if (g2.phase != GamePhase.propertyDecision) return;
    final r = buy ? engine.buyTile(g2, ai.id) : engine.declinePurchase(g2, ai.id);
    _apply(r);
    if (r.isOk) {
      if (r.state!.phase == GamePhase.auctioning) {
        state = state.copyWith(aiActing: false);
        _scheduleAuctionAi(r.state!);
      } else {
        await Future.delayed(const Duration(milliseconds: 600));
        await _finish(r.state!, ai.id);
      }
    } else {
      // ناتوانێت بکڕێت — مزایەدە
      final r2 = engine.declinePurchase(g2, ai.id);
      _apply(r2);
    }
  }

  Future<void> _finish(GameState g, String playerId) async {
    if (!_active) return;
    if (g.phase == GamePhase.gameOver) {
      await _onGameOver(g);
      return;
    }
    if (g.phase != GamePhase.endTurn) return;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!_active) return;
    final r = engine.finishRound(g, playerId);
    _apply(r);
    if (!r.isOk) {
      state = state.copyWith(aiActing: false);
      return;
    }
    final g2 = r.state!;
    await LocalPersistence.saveGame(g2);
    if (g2.phase == GamePhase.gameOver) {
      await _onGameOver(g2);
      return;
    }
    _maybeHandoff(g2, playerId);
    _maybeRunAi();
    if (!_isAi(g2.currentPlayer)) {
      state = state.copyWith(aiActing: false);
    }
  }

  Future<void> _onGameOver(GameState g) async {
    state = state.copyWith(aiActing: false, busy: false);
    await LocalPersistence.clearGame();
    // نوێکردنەوەی پرۆفایل (XP/بردنەوە)
    final winner = g.playerById(g.winnerId);
    final profile = await LocalPersistence.loadProfile();
    final isLocalWin = winner != null && winner.kind == PlayerKind.human;
    final localHumans = g.players.where((p) => p.kind == PlayerKind.human).toList();
    if (localHumans.isNotEmpty) {
      profile['games'] = (profile['games'] as int? ?? 0) + 1;
      if (isLocalWin && localHumans.any((h) => h.id == winner.id)) {
        profile['wins'] = (profile['wins'] as int? ?? 0) + 1;
        profile['coins'] = (profile['coins'] as int? ?? 0) + 500;
        await ref.read(achievementsProvider.notifier).unlock('first_win');
        try {
          ref.read(challengeProvider.notifier).incrementProgress('win_3');
        } catch (_) {}
      }
      profile['xp'] = (profile['xp'] as int? ?? 0) + 120 + (isLocalWin ? 180 : 0);
      final level = ((profile['xp'] as int) ~/ 1000) + 1;
      profile['level'] = level;
      // ئەگەر ١٠٠٠٠ زێڕ کۆبوو بێت
      if (g.netWorth(g.winnerId) >= 10000) {
        await ref.read(achievementsProvider.notifier).unlock('rich');
      }
      await LocalPersistence.saveProfile(profile);
    }
    // تۆماری تۆماری یاری
    final duration = DateTime.now().difference(_gameStartTime).inSeconds;
    final record = {
      'winnerId': g.winnerId,
      'winnerName': winner?.name ?? '',
      'playerNames': g.players.map((p) => p.name).toList(),
      'round': g.round,
      'durationSeconds': duration,
      'moneyEarned': _moneyEarned,
      'propertiesOwned': winner != null ? g.playerProperties(winner.id).length : 0,
      'tradesCompleted': _totalTrades,
      'auctionsWon': _totalAuctionsWon,
      'diceRolled': _totalDiceRolled,
      'finalNetWorth': winner != null ? g.netWorth(winner.id) : 0,
      'playedAt': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      ref.read(matchHistoryProvider.notifier).addRecord(record);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // دەرچوون
  // ------------------------------------------------------------------

  void quitGame() {
    LocalPersistence.clearGame();
    _aiTimer?.cancel();
    state = const GameSession();
  }

  void leaveToSave() {
    if (state.hasGame) LocalPersistence.saveGame(state.game!);
    _aiTimer?.cancel();
    state = const GameSession();
  }
}
