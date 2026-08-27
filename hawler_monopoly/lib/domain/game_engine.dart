import 'dart:math' as math;

import '../data/game/hawler_board.dart';
import 'models/game_models.dart';

/// ئەنجامی یەکسانی (OK یان Error) بۆ هەموو فەرمانەکانی ئەندازە.
class GameResult<T> {
  final T? state;
  final GameRuleError? error;
  const GameResult._(this.state, this.error);
  GameResult.ok(T s) : this._(s, null);
  GameResult.error(String code, String msg) : this._(null, GameRuleError(code, msg));
  bool get isOk => error == null && state != null;
  bool get isError => error != null;
}

/// پێکهاتەی سەرەتایی بۆ دروستکردنی یاریزان.
class PlayerSetup {
  final String id;
  final String name;
  final String characterId;
  final PlayerKind kind;
  final AiDifficulty aiDifficulty;
  final AiPersonality aiPersonality;
  const PlayerSetup({
    required this.id,
    required this.name,
    required this.characterId,
    this.kind = PlayerKind.human,
    this.aiDifficulty = AiDifficulty.medium,
    this.aiPersonality = AiPersonality.balanced,
  });
}

/// ئەندازەی یاسایی یاری — هەموو فەرمانێک لێرەدا پشتڕاست دەکرێتەوە
/// و هیچ گۆڕانکارییەک بەبێ پشکنین ڕوو نادات.
///
/// ئەم چینە بێبەستەرە بە UI — لە هەردوو دۆخی ناوخۆیی و
/// ھاوکاتسازی ئۆنلاین (Firestore) بەکاردهێنرێت.
class GameEngine {
  final math.Random random;
  final List<String> log = [];
  final List<String> usedChanceIds = [];
  final List<String> usedEventIds = [];

  GameEngine({math.Random? random}) : random = random ?? math.Random();

  static const int minPlayers = 2;
  static const int maxPlayers = 6;
  static const int bailCost = 50;
  static const int jailMaxTurns = 3;
  static const int speedRollThreshold = 3;

  // ------------------------------------------------------------------
  // دروستکردنی یاری
  // ------------------------------------------------------------------

  GameResult<GameState> createGame({
    required List<TileDefinition> board,
    required List<PlayerSetup> setups,
    int startCash = HawlerBoard.startCash,
    int? seed,
  }) {
    if (setups.length < minPlayers) {
      return GameResult.error('NEED_PLAYERS', 'لانی کەم $minPlayers یاریزان پێویستە.');
    }
    if (setups.length > maxPlayers) {
      return GameResult.error('FULL', 'زۆرترین ژمارەی یاریزان $maxPlayersـە.');
    }
    final ids = setups.map((s) => s.id).toSet();
    if (ids.length != setups.length) {
      return GameResult.error('DUP_ID', 'ناسنامەی دووبارە بوونی هەیە.');
    }
    final players = <Player>[];
    for (var i = 0; i < setups.length; i++) {
      final s = setups[i];
      if (s.name.trim().isEmpty) {
        return GameResult.error('EMPTY_NAME', 'ناوی یاریزان نابێت بەتاڵ بێت.');
      }
      players.add(Player(
        id: s.id,
        name: s.name.trim(),
        colorIndex: i,
        characterId: s.characterId,
        kind: s.kind,
        aiDifficulty: s.aiDifficulty,
        aiPersonality: s.aiPersonality,
        cash: startCash,
      ));
    }
    final state = GameState(
      board: board,
      players: players,
      tiles: const {},
      phase: GamePhase.awaitingRoll,
      startedAt: DateTime.now(),
      seed: seed ?? random.nextInt(1 << 30),
    );
    log.add('یارییەکە دەستی پێکرد بە ${players.length} یاریزان');
    return GameResult.ok(state);
  }

  // ------------------------------------------------------------------
  // یارمەتیدەرە هاوبەشەکان
  // ------------------------------------------------------------------

  GameResult<GameState> _wrongTurn(GameState s, String playerId) => GameResult.error(
        'WRONG_TURN',
        'ئێستا ڕیزی ${s.currentPlayer?.name ?? '—'}ـە، نەوەک ${_name(s, playerId)}.',
      );

  String _name(GameState s, String id) => s.playerById(id)?.name ?? '؟';

  bool _ownsTile(GameState s, int tileIndex, String ownerId) => s.tiles[tileIndex]?.ownerId == ownerId;

  /// گواستنەوەی دراو بە پشتڕاستکردنەوەی تەواو.
  GameResult<GameState> _transfer({
    required GameState state,
    required String from,
    required String to,
    required int amount,
    required TransactionReason reason,
  }) {
    if (amount < 0) return GameResult.error('NEGATIVE', 'بڕی دراو ناتوانێت نەرێنی بێت.');
    if (amount == 0) return GameResult.ok(state);
    final players = List<Player>.of(state.players);
    final ti = from == MoneyTransaction.bank ? -1 : state.indexOfPlayer(from);
    if (from != MoneyTransaction.bank && ti == -1) return GameResult.error('NO_PLAYER', 'یاریزان نەدۆزرایەوە.');
    if (from != MoneyTransaction.bank && players[ti].cash < amount) {
      return GameResult.error('INSUFFICIENT', '${players[ti].name} دراوی بەس نییە.');
    }
    final updated = <Player>[];
    for (final p in players) {
      var np = p;
      if (p.id == from) np = np.copyWith(cash: np.cash - amount);
      if (p.id == to) np = np.copyWith(cash: np.cash + amount);
      updated.add(np);
    }
    final tx = MoneyTransaction(
      fromPlayerId: from,
      toPlayerId: to,
      amount: amount,
      reason: reason,
      at: DateTime.now().millisecondsSinceEpoch,
    );
    return GameResult.ok(state.copyWith(players: updated, transactions: [...state.transactions, tx]));
  }

  /// پارەدان لەگەڵ فرۆشتنی ئۆتۆماتیکی (بینا/بارمتە) ئەگەر دراو کەم بوو،
  /// ئەگینا پەرەوی.
  GameResult<GameState> _payOrLiquidate({
    required GameState state,
    required String payerId,
    required String to,
    required int amount,
    required TransactionReason reason,
    GamePhase nextPhase = GamePhase.endTurn,
  }) {
    var s = state;
    Player payer = s.playerById(payerId)!;
    if (payer.cash >= amount) {
      final r = _transfer(state: s, from: payerId, to: to, amount: amount, reason: reason);
      if (!r.isOk) return r;
      return GameResult.ok(r.state!.copyWith(phase: nextPhase));
    }

    // ١) فرۆشتنی بیناکان بە نیوە نرخ
    bool soldSomething = true;
    while (s.playerById(payerId)!.cash < amount && soldSomething) {
      soldSomething = false;
      for (final ts in s.tiles.values.toList()) {
        if (ts.ownerId != payerId || ts.level == 0) continue;
        final def = s.board[ts.tileIndex];
        final refund = (def.upgradeCost ~/ 2) * ts.level;
        final tiles = Map<int, TileState>.of(s.tiles);
        tiles[ts.tileIndex] = ts.copyWith(level: 0);
        s = s.copyWith(tiles: tiles);
        final r = _transfer(state: s, from: MoneyTransaction.bank, to: payerId, amount: refund, reason: TransactionReason.trade);
        if (r.isOk) s = r.state!;
        log.add('${_name(s, payerId)} بینا فرۆشت لە «${def.name}» ($refund).');
        soldSomething = true;
        break;
      }
    }

    // ٢) بارمتەکردنی موڵکەکان بە نیوە نرخ
    bool mortgagedSomething = true;
    while (s.playerById(payerId)!.cash < amount && mortgagedSomething) {
      mortgagedSomething = false;
      final candidates = s.tiles.values
          .where((t) => t.ownerId == payerId && !t.mortgaged && t.level == 0)
          .toList()
        ..sort((a, b) => s.board[a.tileIndex].price.compareTo(s.board[b.tileIndex].price));
      for (final ts in candidates) {
        final def = s.board[ts.tileIndex];
        final loan = def.price ~/ 2;
        final tiles = Map<int, TileState>.of(s.tiles);
        tiles[ts.tileIndex] = ts.copyWith(mortgaged: true);
        s = s.copyWith(tiles: tiles);
        final r = _transfer(state: s, from: MoneyTransaction.bank, to: payerId, amount: loan, reason: TransactionReason.mortgageLoan);
        if (r.isOk) s = r.state!;
        log.add('${_name(s, payerId)} بارمتەی کرد «${def.name}» ($loan).');
        mortgagedSomething = true;
        break;
      }
    }

    payer = s.playerById(payerId)!;
    if (payer.cash >= amount) {
      final r = _transfer(state: s, from: payerId, to: to, amount: amount, reason: reason);
      if (!r.isOk) return r;
      return GameResult.ok(r.state!.copyWith(phase: nextPhase));
    }
    return _handleBankruptcy(s, payerId, to);
  }

  GameResult<GameState> _handleBankruptcy(GameState state, String poorId, String creditorId) {
    final poor = state.playerById(poorId);
    if (poor == null || poor.bankrupt) return GameResult.error('BANKRUPT', 'یاریزان پەرەو بووە.');
    var s = state;
    // دراوی ماوە دەدرێت بە قەرزدار (یاریزان یان بانک)
    if (poor.cash > 0 && creditorId != MoneyTransaction.bank) {
      final r = _transfer(state: s, from: poorId, to: creditorId, amount: poor.cash, reason: TransactionReason.rent);
      if (r.isOk) s = r.state!;
    }
    // هەموو موڵکەکان دەگەڕێنەوە بۆ بانک (یان قەرزدار ئەگەر یاریزان بوو)
    final tiles = <int, TileState>{};
    s.tiles.forEach((idx, ts) {
      if (ts.ownerId != poorId) {
        tiles[idx] = ts;
      } else if (creditorId != MoneyTransaction.bank) {
        tiles[idx] = TileState(tileIndex: idx, ownerId: creditorId, level: ts.level, mortgaged: true);
      }
    });
    final players = s.players
        .map((p) => p.id == poorId
            ? p.copyWith(cash: 0, bankrupt: true, propertiesOwned: 0, inJail: false)
            : p)
        .toList();
    if (creditorId != MoneyTransaction.bank) {
      final gained = s.tiles.values.where((t) => t.ownerId == poorId).length;
      for (var i = 0; i < players.length; i++) {
        if (players[i].id == creditorId) {
          players[i] = players[i].copyWith(propertiesOwned: players[i].propertiesOwned + gained);
        }
      }
    }
    log.add('${poor.name} پەرەوی بوو! 💥');
    final alive = players.where((p) => !p.bankrupt).toList();
    final winner = alive.length == 1 ? alive.first : null;
    return GameResult.ok(s.copyWith(
      players: players,
      tiles: tiles,
      phase: winner != null ? GamePhase.gameOver : GamePhase.endTurn,
      winnerId: winner?.id ?? '',
    ));
  }

  // ------------------------------------------------------------------
  // بەرد و جوڵان
  // ------------------------------------------------------------------

  GameResult<GameState> rollDice(GameState state, String playerId, {List<int>? forcedDice}) {
    if (state.phase != GamePhase.awaitingRoll) {
      return GameResult.error('BAD_PHASE', 'ئێستا کاتی داوەدان نییە.');
    }
    final cur = state.currentPlayer;
    if (cur == null || cur.bankrupt) return GameResult.error('NO_PLAYER', 'یاریزانی چالاک نییە.');
    if (cur.id != playerId) return _wrongTurn(state, playerId);

    // ئەگەر ئێرژی هەیە، کەم بکە
    if (state.diceEnergy <= 0) {
      return GameResult.error('NO_ENERGY', 'ئێرژی بەرد تەواوبووە! چاوەڕوانبە یان ئێرژی بیان وەربگرە.');
    }

    if (forcedDice != null && (forcedDice.length != 2 || forcedDice.any((d) => d < 1 || d > 6))) {
      return GameResult.error('BAD_DICE', 'ژمارەی بەرد نادروستە.');
    }
    final d1 = forcedDice?[0] ?? random.nextInt(6) + 1;
    final d2 = forcedDice?[1] ?? random.nextInt(6) + 1;
    final doubles = d1 == d2;
    final newDoubles = doubles ? cur.doublesInARow + 1 : 0;

    log.add('${cur.name}: بەرد ($d1 + $d2)${doubles ? ' — دووانە!' : ''}');

    final players = state.players.map((p) => p.id == playerId ? p.copyWith(doublesInARow: newDoubles) : p).toList();

    // کەمکردنەوەی ئێرژی
    final newEnergy = (state.diceEnergy - 1).clamp(0, state.maxDiceEnergy);

    // سێ دووانە بەردەوام = زیندان
    if (newDoubles >= speedRollThreshold) {
      final jailed = players.map((p) => p.id == playerId ? p.copyWith(inJail: true, jailTurns: 0, doublesInARow: 0, position: 10) : p).toList();
      return GameResult.ok(state.copyWith(players: jailed, dice: [d1, d2], phase: GamePhase.endTurn, diceEnergy: newEnergy));
    }

    return GameResult.ok(state.copyWith(players: players, dice: [d1, d2], phase: GamePhase.rolling, diceEnergy: newEnergy));
  }

  /// جێبەجێکردنی جوڵان (دوای ئەنیمەیشنی UI).
  GameResult<GameState> movePlayer(GameState state, String playerId) {
    if (state.phase != GamePhase.rolling && state.phase != GamePhase.moving) {
      return GameResult.error('BAD_PHASE', 'ئێستا کاتی جوڵان نییە.');
    }
    final cur = state.currentPlayer;
    if (cur == null || cur.id != playerId) return _wrongTurn(state, playerId);

    final steps = state.dice.fold(0, (a, b) => a + b);
    final boardLen = state.board.length;
    final from = cur.position;
    final to = (from + steps) % boardLen;
    final reallyPassed = steps > 0 && (from + steps) >= boardLen;

    var cash = cur.cash;
    var txs = state.transactions;
    if (reallyPassed) {
      final salary = (HawlerBoard.startSalary * state.diceMultiplier).round();
      cash += salary;
      txs = [
        ...txs,
        MoneyTransaction(fromPlayerId: MoneyTransaction.bank, toPlayerId: playerId, amount: salary, reason: TransactionReason.salary, at: DateTime.now().millisecondsSinceEpoch),
      ];
      log.add('مووچەی دەستپێک: +$salary بۆ ${cur.name}${state.diceMultiplier > 1 ? ' (×${state.diceMultiplier})' : ''}');
    }

    final players = state.players.map((p) => p.id == playerId ? p.copyWith(position: to, cash: cash) : p).toList();
    log.add('${cur.name} چووە بۆ «${state.board[to].name}»');
    return GameResult.ok(state.copyWith(players: players, transactions: txs, phase: GamePhase.landing));
  }

  // ------------------------------------------------------------------
  // گەیشتن بە خانە
  // ------------------------------------------------------------------

  GameResult<GameState> resolveLanding(GameState state, String actorId) {
    if (state.phase != GamePhase.landing) return GameResult.error('BAD_PHASE', 'دۆخی گەیشتن چالاک نییە.');
    final cur = state.currentPlayer!;
    if (cur.id != actorId) return _wrongTurn(state, actorId);

    final tile = state.board[cur.position];
    final ts = state.tiles[cur.position];

    switch (tile.type) {
      case TileType.corner:
        return _resolveCorner(state, tile);
      case TileType.tax:
        return _payOrLiquidate(state: state, payerId: cur.id, to: MoneyTransaction.bank, amount: tile.taxAmount, reason: TransactionReason.tax);
      case TileType.chance:
      case TileType.event:
        return GameResult.ok(state.copyWith(phase: GamePhase.cardEvent));
      case TileType.property:
      case TileType.station:
        final owner = ts?.ownerId;
        if (owner == null) {
          if (cur.cash < tile.price) {
            return GameResult.ok(state.copyWith(phase: GamePhase.propertyDecision));
          }
          return GameResult.ok(state.copyWith(phase: GamePhase.propertyDecision));
        }
        if (owner == cur.id) return _collectIncome(state, cur, tile);
        final tsv = ts!;
        if (tsv.mortgaged) {
          log.add('«${tile.name}» بارمتەیە — کرێ وەرنەگیرا.');
          return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
        }
        return _chargeRent(state, cur, tile, tsv, owner);
    }
  }

  GameResult<GameState> _resolveCorner(GameState state, TileDefinition tile) {
    final cur = state.currentPlayer!;
    switch (tile.corner) {
      case CornerKind.start:
        final r = _transfer(state: state, from: MoneyTransaction.bank, to: cur.id, amount: HawlerBoard.startSalary, reason: TransactionReason.salary);
        if (!r.isOk) return r;
        return GameResult.ok(r.state!.copyWith(phase: GamePhase.endTurn));
      case CornerKind.goToJail:
        return sendToJail(state, cur.id);
      case CornerKind.freeParking:
        if (state.freeCoins <= 0) return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
        final r = _transfer(state: state, from: MoneyTransaction.bank, to: cur.id, amount: state.freeCoins, reason: TransactionReason.reward);
        if (!r.isOk) return r;
        log.add('${cur.name} پارکینگی خۆڕایی: +${state.freeCoins}');
        return GameResult.ok(r.state!.copyWith(phase: GamePhase.endTurn, freeCoins: 0));
      case CornerKind.jail:
      case CornerKind.none:
        return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
    }
  }

  double _eventRentMultiplier(GameState state, TileDefinition tile) {
    final ev = state.activeEvent;
    if (ev == null) return 1.0;
    if (ev.type == GameEventType.tourismBoom || ev.type == GameEventType.festival) return ev.rentMultiplier;
    if (ev.type == GameEventType.traffic && tile.isStation) return ev.rentMultiplier;
    return 1.0;
  }

  bool _isMonopolyGroup(GameState state, int group, String ownerId) {
    var total = 0;
    var owned = 0;
    for (final def in state.board) {
      if (def.type != TileType.property || def.group != group) continue;
      total++;
      if (state.tiles[def.index]?.ownerId == ownerId) owned++;
    }
    return total > 0 && total == owned;
  }

  /// کرێی خانە — یاسا تەواوەکان (گروپی تەواو دوو ئەوەندە، کارەبا/ئاو، ڕووداو).
  int computeRent(GameState state, TileDefinition tile, TileState ts) {
    final evMult = _eventRentMultiplier(state, tile);
    if (tile.isStation) {
      final count = state.ownedStations(ts.ownerId!).clamp(1, 4);
      return (tile.rentAtLevel(count - 1) * evMult).round();
    }
    var rent = tile.rentAtLevel(ts.level);
    if (ts.level == 0 && _isMonopolyGroup(state, tile.group, ts.ownerId!)) rent *= 2;
    return (rent * evMult).round();
  }

  GameResult<GameState> _collectIncome(GameState state, Player owner, TileDefinition tile) {
    final ts = state.tiles[tile.index];
    if (tile.isStation) return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
    if (ts == null || ts.mortgaged) return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
    final baseIncome = tile.maintenance + ts.level * 5;
    if (baseIncome <= 0) return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
    final income = (baseIncome * state.diceMultiplier).round();
    final r = _transfer(state: state, from: MoneyTransaction.bank, to: owner.id, amount: income, reason: TransactionReason.salary);
    if (!r.isOk) return r;
    log.add('داهاتی «${tile.name}» بۆ ${owner.name}: +$income${state.diceMultiplier > 1 ? ' (×${state.diceMultiplier})' : ''}');
    return GameResult.ok(r.state!.copyWith(phase: GamePhase.endTurn));
  }

  GameResult<GameState> _chargeRent(GameState state, Player tenant, TileDefinition tile, TileState ts, String ownerId) {
    final rent = computeRent(state, tile, ts);
    if (rent <= 0) return GameResult.ok(state.copyWith(phase: GamePhase.endTurn));
    log.add('کرێی «${tile.name}»: ${tenant.name} دەدات بە ${_name(state, ownerId)} = $rent');
    return _payOrLiquidate(state: state, payerId: tenant.id, to: ownerId, amount: rent, reason: TransactionReason.rent);
  }

  // ------------------------------------------------------------------
  // زیندان
  // ------------------------------------------------------------------

  GameResult<GameState> sendToJail(GameState state, String playerId) {
    final players = state.players
        .map((p) => p.id == playerId ? p.copyWith(inJail: true, jailTurns: 0, position: 10, doublesInARow: 0) : p)
        .toList();
    log.add('${_name(state, playerId)} برا بۆ زیندان. ⚖️');
    return GameResult.ok(state.copyWith(players: players, phase: GamePhase.endTurn));
  }

  GameResult<GameState> payBail(GameState state, String playerId) {
    final p = state.playerById(playerId);
    if (p == null || !p.inJail) return GameResult.error('NOT_JAIL', 'لە زیندان نیت.');
    final r = _transfer(state: state, from: playerId, to: MoneyTransaction.bank, amount: bailCost, reason: TransactionReason.bail);
    if (!r.isOk) return r;
    final players = r.state!.players.map((pl) => pl.id == playerId ? pl.copyWith(inJail: false) : pl).toList();
    log.add('${p.name} بە $bailCost دەرچوو لە زیندان.');
    return GameResult.ok(r.state!.copyWith(players: players, phase: GamePhase.rolling));
  }

  GameResult<GameState> useJailCard(GameState state, String playerId) {
    final p = state.playerById(playerId);
    if (p == null || !p.inJail) return GameResult.error('NOT_JAIL', 'لە زیندان نیت.');
    final players = state.players.map((pl) => pl.id == playerId ? pl.copyWith(inJail: false) : pl).toList();
    log.add('${p.name} بە کارتی ئازادی دەرچوو لە زیندان.');
    return GameResult.ok(state.copyWith(players: players, phase: GamePhase.rolling));
  }

  /// لە دۆخی زیندان: هەوڵی دووانە بەرد یان دەرچوون.
  GameResult<GameState> jailTurn(GameState state, String playerId, {List<int>? forcedDice}) {
    if (state.phase != GamePhase.awaitingRoll) return GameResult.error('BAD_PHASE', 'دۆخ نادروستە.');
    final cur = state.currentPlayer;
    if (cur == null || cur.id != playerId || !cur.inJail) return GameResult.error('NOT_JAIL', 'لە زیندان نیت.');
    final d1 = forcedDice?[0] ?? random.nextInt(6) + 1;
    final d2 = forcedDice?[1] ?? random.nextInt(6) + 1;
    if (d1 == d2) {
      final players = state.players.map((p) => p.id == playerId ? p.copyWith(inJail: false, jailTurns: 0) : p).toList();
      log.add('${cur.name} دووانەی بەرد ($d1,$d2) — دەرچوو لە زیندان!');
      return GameResult.ok(state.copyWith(players: players, dice: [d1, d2], phase: GamePhase.rolling));
    }
    final turns = cur.jailTurns + 1;
    if (turns >= jailMaxTurns) {
      // دوای ٣ دۆرە دەبێت پارە بدات و بچێتە دەرەوە
      var s = state;
      if (s.playerById(playerId)!.cash < bailCost) {
        final liquid = _payOrLiquidate(state: s, payerId: playerId, to: MoneyTransaction.bank, amount: bailCost, reason: TransactionReason.bail);
        if (!liquid.isOk) return liquid;
        s = liquid.state!.copyWith(phase: GamePhase.rolling);
      } else {
        final r = _transfer(state: s, from: playerId, to: MoneyTransaction.bank, amount: bailCost, reason: TransactionReason.bail);
        if (!r.isOk) return r;
        s = r.state!.copyWith(phase: GamePhase.rolling);
      }
      final players = s.players.map((p) => p.id == playerId ? p.copyWith(inJail: false, jailTurns: 0) : p).toList();
      log.add('${cur.name} دوای ٣ دۆرە $bailCost دا و دەرچوو.');
      return GameResult.ok(s.copyWith(players: players, dice: [d1, d2]));
    }
    final players = state.players.map((p) => p.id == playerId ? p.copyWith(jailTurns: turns) : p).toList();
    log.add('${cur.name} بەردی ($d1,$d2) — دووانە نەبوو، لە زیندان مایەوە.');
    return GameResult.ok(state.copyWith(players: players, dice: [d1, d2], phase: GamePhase.endTurn));
  }

  // ------------------------------------------------------------------
  // کڕین / فرۆشتن / بارمتە / بەرزکردنەوە
  // ------------------------------------------------------------------

  int effectivePrice(GameState state, TileDefinition def) {
    final ev = state.activeEvent;
    if (ev == null) return def.price;
    return (def.price * ev.priceMultiplier).round();
  }

  GameResult<GameState> buyTile(GameState state, String playerId, {int? tileIndex}) {
    final cur = state.currentPlayer;
    if (cur == null || cur.id != playerId) return _wrongTurn(state, playerId);
    if (state.phase != GamePhase.propertyDecision) return GameResult.error('BAD_PHASE', 'دۆخی بڕیار چالاک نییە.');
    final idx = tileIndex ?? cur.position;
    final def = state.board[idx];
    if (!def.isBuyable) return GameResult.error('NOT_BUYABLE', 'ئەم خانەیە ناکڕدرێت.');
    if (state.tiles[idx] != null) return GameResult.error('OWNED', 'ئەم خانەیە خاوەنی هەیە.');

    final price = effectivePrice(state, def);
    final r = _transfer(state: state, from: playerId, to: MoneyTransaction.bank, amount: price, reason: TransactionReason.purchase);
    if (!r.isOk) return r;
    final s2 = r.state!;
    final tiles = Map<int, TileState>.of(s2.tiles);
    tiles[idx] = TileState(tileIndex: idx, ownerId: playerId);
    final players = s2.players.map((pl) => pl.id == playerId ? pl.copyWith(propertiesOwned: pl.propertiesOwned + 1) : pl).toList();
    log.add('${cur.name} کڕی «${def.name}» بە $price. 🏠');
    // زیادکردنی ئێرژی بۆ هەر خانەیەکی نوێ
    final bonusEnergy = 1;
    final newEnergy = (s2.diceEnergy + bonusEnergy).clamp(0, s2.maxDiceEnergy);
    return GameResult.ok(s2.copyWith(tiles: tiles, players: players, phase: GamePhase.endTurn, diceEnergy: newEnergy));
  }

  GameResult<GameState> declinePurchase(GameState state, String playerId) {
    if (state.phase != GamePhase.propertyDecision) return GameResult.error('BAD_PHASE', 'دۆخی بڕیار چالاک نییە.');
    final cur = state.currentPlayer!;
    if (cur.id != playerId) return _wrongTurn(state, playerId);
    final idx = cur.position;
    final def = state.board[idx];
    final auction = AuctionState(tileIndex: idx, endsAt: DateTime.now().millisecondsSinceEpoch + 30000, basePrice: def.price);
    log.add('${cur.name} ڕەتیکردەوە — مزایەدە لەسەر «${def.name}» دەستی پێکرد. 🔨');
    return GameResult.ok(state.copyWith(auction: auction, phase: GamePhase.auctioning));
  }

  GameResult<GameState> upgradeTile(GameState state, String playerId, int tileIndex) {
    if (!_ownsTile(state, tileIndex, playerId)) return GameResult.error('NOT_OWNER', 'تۆ خاوەنی ئەم خانەیە نیت.');
    final def = state.board[tileIndex];
    if (!def.isBuyable || def.isStation) return GameResult.error('NOT_UPGRADABLE', 'ئەم خانەیە بەرز ناکرێتەوە.');
    final ts = state.tiles[tileIndex]!;
    if (ts.mortgaged) return GameResult.error('MORTGAGED', 'خانەکە بارمتەیە — سەرەتا بارمتە لاببە.');
    if (ts.level >= def.maxLevel) return GameResult.error('MAX_LEVEL', 'گەیشتووەتە بەرزترین ئاست.');
    if (!_isMonopolyGroup(state, def.group, playerId)) {
      return GameResult.error('NO_MONOPOLY', 'پێش بەرزکردنەوە دەبێت هەموو خانەکانی ڕەنگەکە بکڕیت.');
    }
    var cost = def.upgradeCost;
    if (state.activeEvent?.type == GameEventType.construction) cost = (cost * 0.5).round();
    final r = _transfer(state: state, from: playerId, to: MoneyTransaction.bank, amount: cost, reason: TransactionReason.upgrade);
    if (!r.isOk) return r;
    final s2 = r.state!;
    final tiles = Map<int, TileState>.of(s2.tiles);
    tiles[tileIndex] = ts.copyWith(level: ts.level + 1);
    log.add('${_name(state, playerId)} «${def.name}» بەرزیکرد بۆ ئاست ${ts.level + 1}. 🏗️');
    return GameResult.ok(s2.copyWith(tiles: tiles));
  }

  GameResult<GameState> mortgageTile(GameState state, String playerId, int tileIndex) {
    if (!_ownsTile(state, tileIndex, playerId)) return GameResult.error('NOT_OWNER', 'تۆ خاوەنی ئەم خانەیە نیت.');
    final def = state.board[tileIndex];
    final ts = state.tiles[tileIndex]!;
    if (ts.mortgaged) return GameResult.error('MORTGAGED', 'پێشتر بارمتە کراوە.');
    if (ts.level > 0) return GameResult.error('HAS_BUILDINGS', 'سەرەتا بیناکان دابەزێنە.');
    final loan = def.price ~/ 2;
    final r = _transfer(state: state, from: MoneyTransaction.bank, to: playerId, amount: loan, reason: TransactionReason.mortgageLoan);
    if (!r.isOk) return r;
    final s2 = r.state!;
    final tiles = Map<int, TileState>.of(s2.tiles);
    tiles[tileIndex] = ts.copyWith(mortgaged: true);
    log.add('${_name(state, playerId)} بارمتەی کرد «${def.name}» بۆ $loan.');
    return GameResult.ok(s2.copyWith(tiles: tiles));
  }

  GameResult<GameState> unmortgageTile(GameState state, String playerId, int tileIndex) {
    if (!_ownsTile(state, tileIndex, playerId)) return GameResult.error('NOT_OWNER', 'تۆ خاوەنی ئەم خانەیە نیت.');
    final def = state.board[tileIndex];
    final ts = state.tiles[tileIndex]!;
    if (!ts.mortgaged) return GameResult.error('NOT_MORTGAGED', 'بارمتە نییە.');
    final cost = (def.price ~/ 2 * 1.1).round();
    final r = _transfer(state: state, from: playerId, to: MoneyTransaction.bank, amount: cost, reason: TransactionReason.unmortgage);
    if (!r.isOk) return r;
    final s2 = r.state!;
    final tiles = Map<int, TileState>.of(s2.tiles);
    tiles[tileIndex] = ts.copyWith(mortgaged: false);
    log.add('${_name(state, playerId)} بارمتەی لابرد لە «${def.name}».');
    return GameResult.ok(s2.copyWith(tiles: tiles));
  }

  GameResult<GameState> sellTile(GameState state, String playerId, int tileIndex) {
    if (!_ownsTile(state, tileIndex, playerId)) return GameResult.error('NOT_OWNER', 'تۆ خاوەنی ئەم خانەیە نیت.');
    final def = state.board[tileIndex];
    final ts = state.tiles[tileIndex]!;
    final salePrice = (def.price * 0.6).round() + ts.level * (def.upgradeCost ~/ 2);
    final r = _transfer(state: state, from: MoneyTransaction.bank, to: playerId, amount: salePrice, reason: TransactionReason.trade);
    if (!r.isOk) return r;
    final s2 = r.state!;
    final tiles = Map<int, TileState>.of(s2.tiles);
    tiles.remove(tileIndex);
    final players = s2.players.map((pl) => pl.id == playerId ? pl.copyWith(propertiesOwned: (pl.propertiesOwned - 1).clamp(0, 999)) : pl).toList();
    log.add('${_name(state, playerId)} فرۆشتی «${def.name}» بە $salePrice.');
    return GameResult.ok(s2.copyWith(tiles: tiles, players: players));
  }

  // ------------------------------------------------------------------
  // کارتەکان
  // ------------------------------------------------------------------

  GameResult<GameState> drawCard(GameState state, String actorId, {GameCard? forcedCard}) {
    if (state.phase != GamePhase.cardEvent) return GameResult.error('BAD_PHASE', 'دۆخی کارت چالاک نییە.');
    final cur = state.currentPlayer!;
    if (cur.id != actorId) return _wrongTurn(state, actorId);
    final idx = cur.position;
    final def = state.board[idx];
    final isEvent = def.type == TileType.event;
    final deck = isEvent ? EventDeck.cards : ChanceDeck.cards;
    final used = isEvent ? usedEventIds : usedChanceIds;
    final available = deck.where((c) => !used.contains(c.id)).toList();
    final card = forcedCard ?? (available.isEmpty
        ? deck[RandomHelper.nextInt(random, deck.length)]
        : available[RandomHelper.nextInt(random, available.length)]);
    if (!used.contains(card.id)) used.add(card.id);
    log.add('کارت: «${card.title}» — ${card.description}');

    final s = state.copyWith(lastCardId: card.id);

    switch (card.effect) {
      case CardEffect.gainMoney:
        if (isEvent && card.amount == 0) return _applyGlobalEventCard(s, card);
        if (isEvent && card.amount > 0) {
          var s2 = s;
          for (final p in s.players) {
            if (p.bankrupt) continue;
            final r = _transfer(state: s2, from: MoneyTransaction.bank, to: p.id, amount: card.amount, reason: TransactionReason.reward);
            if (r.isOk) s2 = r.state!;
          }
          return GameResult.ok(s2.copyWith(phase: GamePhase.endTurn));
        }
        final boosted = (card.amount * s.diceMultiplier).round();
        final r = _transfer(state: s, from: MoneyTransaction.bank, to: cur.id, amount: boosted, reason: TransactionReason.reward);
        if (!r.isOk) return r;
        log.add('بەخشین کارت: +$boosted${s.diceMultiplier > 1 ? ' (×${s.diceMultiplier})' : ''}');
        return GameResult.ok(r.state!.copyWith(phase: GamePhase.endTurn));
      case CardEffect.loseMoney:
        if (card.amount == 0) return _applyGlobalEventCard(s, card);
        return _payOrLiquidate(state: s, payerId: cur.id, to: MoneyTransaction.bank, amount: card.amount, reason: TransactionReason.fine);
      case CardEffect.moveTo:
        final to = card.targetTileIndex;
        final passedStart = to < cur.position && to != cur.position;
        var cash = cur.cash;
        if (passedStart) cash += HawlerBoard.startSalary;
        final players = s.players.map((p) => p.id == cur.id ? p.copyWith(position: to, cash: cash) : p).toList();
        return GameResult.ok(s.copyWith(players: players, phase: GamePhase.landing));
      case CardEffect.moveBy:
        final boardLen = s.board.length;
        final to = (cur.position + card.amount + boardLen) % boardLen;
        final players = s.players.map((p) => p.id == cur.id ? p.copyWith(position: to) : p).toList();
        return GameResult.ok(s.copyWith(players: players, phase: GamePhase.landing));
      case CardEffect.goToJail:
        return sendToJail(s, cur.id);
      case CardEffect.getOutOfJail:
        log.add('${cur.name} کارتی ئازادی وەرگرت.');
        return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
      case CardEffect.repairAll:
        var cost = 0;
        for (final ts in s.tiles.values) {
          if (ts.ownerId == cur.id) cost += ts.level * card.amount;
        }
        if (cost == 0) return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
        if (isEvent) {
          // ڕووداوی باران: هەموو یاریزانەکان
          var s2 = s;
          for (final p in s.players) {
            if (p.bankrupt) continue;
            var c = 0;
            for (final ts in s2.tiles.values) {
              if (ts.ownerId == p.id) c += ts.level * card.amount;
            }
            if (c > 0) {
              final r = _payOrLiquidate(state: s2, payerId: p.id, to: MoneyTransaction.bank, amount: c, reason: TransactionReason.fine);
              if (r.isOk) s2 = r.state!;
            }
          }
          return GameResult.ok(s2.copyWith(phase: GamePhase.endTurn));
        }
        return _payOrLiquidate(state: s, payerId: cur.id, to: MoneyTransaction.bank, amount: cost, reason: TransactionReason.fine);
      case CardEffect.collectFromAll:
        final boosted = (card.amount * s.diceMultiplier).round();
        var s2 = s;
        for (final p in s.players) {
          if (p.id == cur.id || p.bankrupt) continue;
          final r = _payOrLiquidate(state: s2, payerId: p.id, to: cur.id, amount: boosted, reason: TransactionReason.reward);
          if (r.isOk) s2 = r.state!;
        }
        log.add('کۆکردنەوە: +$boosted لە هەر یاریزانێک${s.diceMultiplier > 1 ? ' (×${s.diceMultiplier})' : ''}');
        final phase = s2.phase == GamePhase.gameOver ? GamePhase.gameOver : GamePhase.endTurn;
        return GameResult.ok(s2.copyWith(phase: phase));
      case CardEffect.doubleRentNextTurn:
        return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
    }
  }

  GameResult<GameState> _applyGlobalEventCard(GameState s, GameCard card) {
    ActiveGameEvent ev;
    final ends = s.round + 2;
    switch (card.id) {
      case 'ev_tourism':
        ev = ActiveGameEvent(type: GameEventType.tourismBoom, name: card.title, description: card.description, rentMultiplier: 1.5, endsAtTurn: ends);
      case 'ev_crisis':
        ev = ActiveGameEvent(type: GameEventType.economicCrisis, name: card.title, description: card.description, priceMultiplier: 0.75, endsAtTurn: ends);
      case 'ev_traffic':
        ev = ActiveGameEvent(type: GameEventType.traffic, name: card.title, description: card.description, rentMultiplier: 2.0, endsAtTurn: ends);
      case 'ev_tea':
        ev = ActiveGameEvent(type: GameEventType.marketChange, name: card.title, description: card.description, rentMultiplier: 1.25, endsAtTurn: ends);
      case 'ev_construction':
        ev = ActiveGameEvent(type: GameEventType.construction, name: card.title, description: card.description, endsAtTurn: ends);
      default:
        return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
    }
    final r = applyGlobalEvent(s, ev);
    if (!r.isOk) return r;
    return GameResult.ok(r.state!.copyWith(phase: GamePhase.endTurn));
  }

  /// وەرگرتنی ڕووداوی گشتی.
  GameResult<GameState> applyGlobalEvent(GameState state, ActiveGameEvent ev) {
    if (state.activeEvent != null) return GameResult.ok(state);
    log.add('ڕووداوی گشتی: ${ev.name} — ${ev.description}');
    return GameResult.ok(state.copyWith(activeEvent: ev));
  }

  // ------------------------------------------------------------------
  // مزایەدە
  // ------------------------------------------------------------------

  GameResult<GameState> placeBid(GameState state, String playerId, int amount) {
    final a = state.auction;
    if (a == null) return GameResult.error('NO_AUCTION', 'مزایەدە چالاک نییە.');
    if (amount <= a.highestBid) return GameResult.error('LOW_BID', 'نرخەکە دەبێت بەرزتر بێت لە ${a.highestBid}.');
    if (amount > a.basePrice) return GameResult.error('OVER_MAX', 'ناتوانیت لە ${a.basePrice} زیاتر بدەیت.');
    final p = state.playerById(playerId);
    if (p == null || p.bankrupt) return GameResult.error('NO_PLAYER', 'یاریزان بەردەست نییە.');
    if (a.passedBidders.contains(playerId)) return GameResult.error('PASSED', 'پێشتر خۆت لە مزایەدە کشاندەوە.');
    if (p.cash < amount) return GameResult.error('INSUFFICIENT', 'دراوت بەس نییە.');
    log.add('${p.name}: $amount لە مزایەدە.');
    return GameResult.ok(state.copyWith(auction: a.copyWith(highestBid: amount, highestBidderId: playerId)));
  }

  GameResult<GameState> passAuction(GameState state, String playerId) {
    final a = state.auction;
    if (a == null) return GameResult.error('NO_AUCTION', 'مزایەدە چالاک نییە.');
    final passed = {...a.passedBidders, playerId};
    final auction = a.copyWith(passedBidders: passed);
    final active = state.players.where((p) => !p.bankrupt && !passed.contains(p.id)).toList();
    if (auction.hasBids) {
      final others = active.where((p) => p.id != auction.highestBidderId).toList();
      if (others.isEmpty) return closeAuction(state.copyWith(auction: auction));
    } else if (active.length <= 1) {
      return closeAuction(state.copyWith(auction: auction));
    }
    return GameResult.ok(state.copyWith(auction: auction));
  }

  GameResult<GameState> closeAuction(GameState state) {
    final a = state.auction;
    if (a == null) return GameResult.error('NO_AUCTION', 'مزایەدە چالاک نییە.');
    GameState s = state.copyWith(clearAuction: true);
    if (!a.hasBids) {
      log.add('مزایەدە بەبێ ئەنجام کۆتایی هات.');
      return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
    }
    final winnerId = a.highestBidderId!;
    final p = state.playerById(winnerId);
    if (p == null || p.cash < a.highestBid) {
      log.add('براوە نەیتوانی پارەکە بدات — خانەکە بەتاڵ دەمێنێت.');
      return GameResult.ok(s.copyWith(phase: GamePhase.endTurn));
    }
    final r = _transfer(state: s, from: winnerId, to: MoneyTransaction.bank, amount: a.highestBid, reason: TransactionReason.auctionWin);
    if (!r.isOk) return r;
    s = r.state!;
    final tiles = Map<int, TileState>.of(s.tiles);
    tiles[a.tileIndex] = TileState(tileIndex: a.tileIndex, ownerId: winnerId);
    final players = s.players.map((pl) => pl.id == winnerId ? pl.copyWith(propertiesOwned: pl.propertiesOwned + 1) : pl).toList();
    log.add('${p.name} بردی مزایەدە: «${s.board[a.tileIndex].name}» بە ${a.highestBid}. 🏆');
    return GameResult.ok(s.copyWith(tiles: tiles, players: players, phase: GamePhase.endTurn));
  }

  // ------------------------------------------------------------------
  // بازرگانی
  // ------------------------------------------------------------------

  GameResult<GameState> proposeTrade(GameState state, TradeOffer offer) {
    if (!offer.isValid) return GameResult.error('BAD_OFFER', 'پێشنیازەکە هیچ ئاڵوگۆڕێکی تێدا نییە.');
    final from = state.playerById(offer.fromPlayerId);
    final to = state.playerById(offer.toPlayerId);
    if (from == null || to == null) return GameResult.error('NO_PLAYER', 'یاریزان نەدۆزرایەوە.');
    if (from.bankrupt || to.bankrupt) return GameResult.error('BANKRUPT', 'یاریزان پەرەو بووە.');
    if (offer.moneyFrom > from.cash) return GameResult.error('INSUFFICIENT', 'دراوی ${from.name} بەس نییە.');
    if (offer.moneyTo > to.cash) return GameResult.error('INSUFFICIENT', 'دراوی ${to.name} بەس نییە.');
    for (final idx in offer.tilesFrom) {
      if (idx < 0 || idx >= state.board.length || !_ownsTile(state, idx, offer.fromPlayerId)) {
        return GameResult.error('NOT_OWNER', '${from.name} خاوەنی ئەو خانەیە نییە.');
      }
    }
    for (final idx in offer.tilesTo) {
      if (idx < 0 || idx >= state.board.length || !_ownsTile(state, idx, offer.toPlayerId)) {
        return GameResult.error('NOT_OWNER', '${to.name} خاوەنی ئەو خانەیە نییە.');
      }
    }
    log.add('پێشنیازی بازرگانی: ${from.name} ↔ ${to.name}');
    return GameResult.ok(state.copyWith(pendingTrade: offer.copyWith(acceptedByFrom: true), phase: GamePhase.trading));
  }

  GameResult<GameState> respondToTrade(GameState state, String playerId, bool accept) {
    final t = state.pendingTrade;
    if (t == null) return GameResult.error('NO_TRADE', 'بازرگانی چالاک نییە.');
    if (playerId != t.toPlayerId && playerId != t.fromPlayerId) {
      return GameResult.error('NOT_INVOLVED', 'تۆ بەشدار نیت لەم بازرگانییە.');
    }
    if (!accept) {
      log.add('بازرگانی ڕەتکرایەوە.');
      return GameResult.ok(state.copyWith(clearTrade: true, phase: GamePhase.endTurn));
    }
    for (final idx in t.tilesFrom) {
      if (!_ownsTile(state, idx, t.fromPlayerId)) return GameResult.error('NOT_OWNER', 'خاوەنایەتی گۆڕاوە — بازرگانی هەڵوەشایەوە.');
    }
    for (final idx in t.tilesTo) {
      if (!_ownsTile(state, idx, t.toPlayerId)) return GameResult.error('NOT_OWNER', 'خاوەنایەتی گۆڕاوە — بازرگانی هەڵوەشایەوە.');
    }
    final updated = playerId == t.fromPlayerId
        ? t.copyWith(acceptedByFrom: true, acceptedByTo: t.acceptedByTo)
        : t.copyWith(acceptedByTo: true, acceptedByFrom: t.acceptedByFrom);
    if (!updated.acceptedByFrom || !updated.acceptedByTo) {
      return GameResult.ok(state.copyWith(pendingTrade: updated));
    }
    return executeTrade(state.copyWith(pendingTrade: updated));
  }

  GameResult<GameState> executeTrade(GameState state) {
    final t = state.pendingTrade;
    if (t == null) return GameResult.error('NO_TRADE', 'بازرگانی چالاک نییە.');
    final from = state.playerById(t.fromPlayerId)!;
    final to = state.playerById(t.toPlayerId)!;
    if (from.cash < t.moneyFrom || to.cash < t.moneyTo) {
      return GameResult.error('INSUFFICIENT', 'دراوی یاریزانان بەس نییە.');
    }
    var s = state;
    if (t.moneyFrom > 0) {
      final r = _transfer(state: s, from: t.fromPlayerId, to: t.toPlayerId, amount: t.moneyFrom, reason: TransactionReason.trade);
      if (!r.isOk) return r;
      s = r.state!;
    }
    if (t.moneyTo > 0) {
      final r = _transfer(state: s, from: t.toPlayerId, to: t.fromPlayerId, amount: t.moneyTo, reason: TransactionReason.trade);
      if (!r.isOk) return r;
      s = r.state!;
    }
    final tiles = Map<int, TileState>.of(s.tiles);
    for (final idx in t.tilesFrom) {
      if (tiles.containsKey(idx)) tiles[idx] = TileState(tileIndex: idx, ownerId: t.toPlayerId);
    }
    for (final idx in t.tilesTo) {
      if (tiles.containsKey(idx)) tiles[idx] = TileState(tileIndex: idx, ownerId: t.fromPlayerId);
    }
    final ownedDelta = t.tilesTo.length - t.tilesFrom.length;
    final players = s.players.map((p) {
      if (p.id == t.fromPlayerId) return p.copyWith(propertiesOwned: (p.propertiesOwned + ownedDelta).clamp(0, 999));
      if (p.id == t.toPlayerId) return p.copyWith(propertiesOwned: (p.propertiesOwned - ownedDelta).clamp(0, 999));
      return p;
    }).toList();
    log.add('بازرگانی تەواوبوو: ${from.name} ↔ ${to.name} 🤝');
    return GameResult.ok(s.copyWith(tiles: tiles, players: players, clearTrade: true, phase: GamePhase.endTurn));
  }

  // ------------------------------------------------------------------
  // کۆتایی سووڕ
  // ------------------------------------------------------------------

  /// تەواوکردنی سووڕ و گواستنەوەی ڕیز.
  GameResult<GameState> finishRound(GameState state, String actorId) {
    if (state.phase != GamePhase.endTurn) return GameResult.error('BAD_PHASE', 'دۆخی کۆتایی سووڕ چالاک نییە.');
    final cur = state.currentPlayer!;
    if (cur.id != actorId) return _wrongTurn(state, actorId);

    GameState s = state;

    // گەڕانەوەی ئێرژی بەپێی ئاست
    var energy = s.diceEnergy + s.energyRegenRate;
    energy = energy.clamp(0, s.maxDiceEnergy);
    s = s.copyWith(diceEnergy: energy);

    // ڕووداوی گشتی هەڕەمەکی
    if (s.round % 3 == 0 && s.activeEvent == null && random.nextDouble() < 0.4) {
      final ev = _randomEvent(s.round);
      final r = applyGlobalEvent(s, ev);
      if (r.isOk) s = r.state!;
    }
    if (s.activeEvent != null && s.round >= s.activeEvent!.endsAtTurn) {
      s = s.copyWith(clearEvent: true);
    }

    // دووانە بەرد = ڕیزی زیادە بۆ هەمان یاریزان
    final curNow = s.playerById(actorId)!;
    if (curNow.doublesInARow > 0 && !curNow.inJail && !curNow.bankrupt) {
      log.add('${curNow.name} ڕیزی زیادەی هەیە (دووانە).');
      return GameResult.ok(s.copyWith(phase: GamePhase.awaitingRoll));
    }

    // دۆزینەوەی یاریزانی داهاتوو
    var nextIndex = s.currentPlayerIndex;
    var round = s.round;
    var guard = 0;
    do {
      nextIndex = (nextIndex + 1) % s.players.length;
      if (nextIndex == 0) round++;
      guard++;
      if (guard > s.players.length * 2) {
        return GameResult.ok(s.copyWith(phase: GamePhase.gameOver, winnerId: _richest(s)));
      }
    } while (s.players[nextIndex].bankrupt);

    final nextPlayer = s.players[nextIndex];
    log.add('— ڕیزی ${nextPlayer.name} —');
    return GameResult.ok(s.copyWith(
      currentPlayerIndex: nextIndex,
      round: round,
      phase: GamePhase.awaitingRoll,
    ));
  }

  ActiveGameEvent _randomEvent(int round) {
    final events = <ActiveGameEvent>[
      ActiveGameEvent(
        type: GameEventType.tourismBoom,
        name: 'گەشتیاری بەرز',
        description: 'گەشتیاران هاتنە هەولێر — کرێ +٥٠٪ بۆ ٢ دۆرە.',
        rentMultiplier: 1.5,
        endsAtTurn: round + 2,
      ),
      ActiveGameEvent(
        type: GameEventType.economicCrisis,
        name: 'قەیرانی ئابووری',
        description: 'نرخی موڵکەکان -٢٥٪ بۆ ٢ دۆرە.',
        priceMultiplier: 0.75,
        endsAtTurn: round + 2,
      ),
      ActiveGameEvent(
        type: GameEventType.traffic,
        name: 'قەرەباڵغی هاتوچۆ',
        description: 'کرێی گاراژەکان دوو ئەوەندە بۆ ٢ دۆرە.',
        rentMultiplier: 2.0,
        endsAtTurn: round + 2,
      ),
      ActiveGameEvent(
        type: GameEventType.festival,
        name: 'فیستیڤاڵی نەورۆز',
        description: 'کرێی هەموو موڵکەکان +٧٥٪ بۆ ٢ دۆرە.',
        rentMultiplier: 1.75,
        endsAtTurn: round + 2,
      ),
      ActiveGameEvent(
        type: GameEventType.governmentSupport,
        name: 'پشتگیری حکومەت',
        description: 'موڵکەکان ١٠٪ زیاتر دەکڕدرێن بۆ ٢ دۆرە.',
        priceMultiplier: 1.1,
        endsAtTurn: round + 2,
      ),
    ];
    return events[random.nextInt(events.length)];
  }

  String _richest(GameState s) {
    var best = s.players.first;
    for (final p in s.players) {
      if (s.netWorth(p.id) > s.netWorth(best.id)) best = p;
    }
    return best.id;
  }
}

/// یارمەتیدەری هەڕەمەکی.
class RandomHelper {
  RandomHelper._();
  static int nextInt(math.Random r, int bound) => bound <= 1 ? 0 : r.nextInt(bound);
}
