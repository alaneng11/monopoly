import 'package:flutter_test/flutter_test.dart';

import 'package:hawler_monopoly/data/game/hawler_board.dart';
import 'package:hawler_monopoly/domain/ai_brain.dart';
import 'package:hawler_monopoly/domain/game_engine.dart';
import 'package:hawler_monopoly/domain/models/game_models.dart';

void main() {
  group('GameEngine — دروستکردنی یاری', () {
    test('لانی کەم ٢ یاریزان پێویستە', () {
      final engine = GameEngine();
      final r = engine.createGame(board: HawlerBoard.build(), setups: [
        const PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
      ]);
      expect(r.isError, isTrue);
    });

    test('٦ یاریزان قبوڵ دەکرێت، ٧ ڕەت دەکرێتەوە', () {
      final engine = GameEngine();
      final six = List.generate(6, (i) => PlayerSetup(id: 'p$i', name: 'P$i', characterId: 'business'));
      expect(engine.createGame(board: HawlerBoard.build(), setups: six).isOk, isTrue);
      final seven = List.generate(7, (i) => PlayerSetup(id: 'p$i', name: 'P$i', characterId: 'business'));
      expect(engine.createGame(board: HawlerBoard.build(), setups: seven).isError, isTrue);
    });

    test('ناسنامەی دووبارە ڕەت دەکرێتەوە', () {
      final engine = GameEngine();
      final r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'x', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'x', name: 'B', characterId: 'doctor'),
      ]);
      expect(r.isError, isTrue);
    });
  });

  group('GameEngine — بەرد و جوڵان', () {
    GameState newGame() {
      final engine = GameEngine();
      final r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      return r.state!;
    }

    test('بەرد دوای ئەنیمەیشن — جوڵان و گەیشتن', () {
      final engine = GameEngine();
      var s = newGame();
      final r = engine.rollDice(s, 'a', forcedDice: [3, 2]);
      expect(r.isOk, isTrue);
      s = r.state!;
      expect(s.phase, GamePhase.rolling);
      final m = engine.movePlayer(s, 'a');
      expect(m.isOk, isTrue);
      s = m.state!;
      expect(s.players[0].position, 5);
      expect(s.phase, GamePhase.landing);
    });

    test('تەنها یاریزانی چالاک دەتوانێت بەرد بداوێنێت', () {
      final engine = GameEngine();
      final s = newGame();
      final r = engine.rollDice(s, 'b', forcedDice: [1, 1]);
      expect(r.isError, isTrue);
      expect(r.error!.code, 'WRONG_TURN');
    });

    test('دووانە بەرد = ڕیزی زیادە', () {
      final engine = GameEngine();
      var s = newGame();
      final r = engine.rollDice(s, 'a', forcedDice: [5, 5]);
      expect(r.isOk, isTrue);
      s = r.state!;
      final m = engine.movePlayer(s, 'a');
      expect(m.isOk, isTrue);
      s = m.state!;
      expect(s.players[0].position, 10); // گۆشەی زیندان — دۆخی کۆتایی
      final l = engine.resolveLanding(s, 'a');
      expect(l.isOk, isTrue);
      s = l.state!;
      expect(s.phase, GamePhase.endTurn);
      final f = engine.finishRound(s, 'a');
      expect(f.isOk, isTrue);
      s = f.state!;
      expect(s.currentPlayer!.id, 'a');
      expect(s.phase, GamePhase.awaitingRoll);
    });
  });

  group('GameEngine — کرێ', () {
    test('کرێی خانەی خاوەندار — پارە دەگوازرێتەوە', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      // خانەی ٣ بکە خاوەنی 'a'
      final tiles = Map<int, TileState>.of(s.tiles);
      tiles[3] = const TileState(tileIndex: 3, ownerId: 'a');
      s = s.copyWith(tiles: tiles);
      // a دەڕوات بۆ خانەی باج (٤) — کرێ نییە، باج دەدات و دۆرە تەواو دەبێت
      var roll = engine.rollDice(s, 'a', forcedDice: [1, 3]);
      expect(roll.isOk, isTrue);
      s = roll.state!;
      var m = engine.movePlayer(s, 'a');
      expect(m.isOk, isTrue);
      s = m.state!;
      var l = engine.resolveLanding(s, 'a');
      expect(l.isOk, isTrue);
      s = l.state!;
      expect(s.phase, GamePhase.endTurn);
      var f = engine.finishRound(s, 'a');
      expect(f.isOk, isTrue);
      s = f.state!;
      expect(s.currentPlayer!.id, 'b');
      // b دەڕوات بۆ خانەی ٣ — کرێ دەدات بە a
      roll = engine.rollDice(s, 'b', forcedDice: [1, 2]);
      expect(roll.isOk, isTrue);
      s = roll.state!;
      m = engine.movePlayer(s, 'b');
      expect(m.isOk, isTrue);
      s = m.state!;
      expect(s.players.firstWhere((p) => p.id == 'b').position, 3);
      l = engine.resolveLanding(s, 'b');
      expect(l.isOk, isTrue);
      s = l.state!;
      final b = s.players.firstWhere((p) => p.id == 'b');
      expect(b.cash, 1500 - 4); // کرێی بنەڕەتی خانەی ٦٠ = ٤
      final a = s.players.firstWhere((p) => p.id == 'a');
      expect(a.cash, 1500 - 100 + 4); // باج دایە + کرێ وەرگرت
    });
  });

  group('GameEngine — بارمتە و فرۆشتن', () {
    test('بارمتەکردن — نیوە نرخ وەردەگیرێت و کرێ ناگیرێت', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      var tiles = Map<int, TileState>.of(s.tiles);
      tiles[1] = const TileState(tileIndex: 1, ownerId: 'a');
      s = s.copyWith(tiles: tiles);
      final before = s.players.firstWhere((p) => p.id == 'a').cash;
      final mor = engine.mortgageTile(s, 'a', 1);
      expect(mor.isOk, isTrue);
      s = mor.state!;
      expect(s.tiles[1]!.mortgaged, isTrue);
      final after = s.players.firstWhere((p) => p.id == 'a').cash;
      expect(after - before, 30); // ٦٠ / ٢
    });

    test('فرۆشتن — ٦٠٪ی نرخ + نیوە بەهای بیناکان', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      var tiles = Map<int, TileState>.of(s.tiles);
      tiles[6] = const TileState(tileIndex: 6, ownerId: 'a', level: 2);
      s = s.copyWith(tiles: tiles);
      final before = s.players.firstWhere((p) => p.id == 'a').cash;
      final sell = engine.sellTile(s, 'a', 6);
      expect(sell.isOk, isTrue);
      s = sell.state!;
      expect(s.tiles[6], isNull);
      final after = s.players.firstWhere((p) => p.id == 'a').cash;
      // ١٠٠ * ٠.٦ + ٢ * (١٠٠/٢) = ٦٠ + ١٠٠
      expect(after - before, 160);
    });
  });

  group('GameEngine — بازرگانی', () {
    test('بازرگانیی دروست — هەردوو لایەن قبوڵ دەکەن', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      var tiles = Map<int, TileState>.of(s.tiles);
      tiles[1] = const TileState(tileIndex: 1, ownerId: 'a');
      s = s.copyWith(tiles: tiles);
      const offer = TradeOffer(
        id: 't1',
        fromPlayerId: 'a',
        toPlayerId: 'b',
        moneyFrom: 0,
        tilesFrom: [1],
      );
      final p = engine.proposeTrade(s, offer);
      expect(p.isOk, isTrue);
      s = p.state!;
      final resp = engine.respondToTrade(s, 'b', true);
      expect(resp.isOk, isTrue);
      s = resp.state!;
      expect(s.tiles[1]!.ownerId, 'b');
      final aCash = s.players.firstWhere((p) => p.id == 'a').cash;
      // a دەبێت دراوی هەمان بێت (هیچ پارەیەک نەدراوە)
      expect(aCash, 1500);
    });

    test('بازرگانیی نایاسایی — خانەی خاوەنی کەسێکی تر', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      var tiles = Map<int, TileState>.of(s.tiles);
      tiles[1] = const TileState(tileIndex: 1, ownerId: 'b');
      s = s.copyWith(tiles: tiles);
      const offer = TradeOffer(id: 't2', fromPlayerId: 'a', toPlayerId: 'b', tilesFrom: [1]);
      final p = engine.proposeTrade(s, offer);
      expect(p.isError, isTrue);
    });
  });

  group('GameEngine — مزایەدە', () {
    test('مزایەدە — بیدەر براوە دەبێت و خانە وەردەگرێت', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      const auction = AuctionState(tileIndex: 3, endsAt: 999999999999, basePrice: 60);
      s = s.copyWith(auction: auction, phase: GamePhase.auctioning);
      var bid = engine.placeBid(s, 'a', 30);
      expect(bid.isOk, isTrue);
      s = bid.state!;
      bid = engine.placeBid(s, 'b', 40);
      expect(bid.isOk, isTrue);
      s = bid.state!;
      final close = engine.closeAuction(s);
      expect(close.isOk, isTrue);
      s = close.state!;
      expect(s.tiles[3]!.ownerId, 'b');
      expect(s.players.firstWhere((p) => p.id == 'b').cash, 1500 - 40);
    });

    test('بیدی نزم ڕەت دەکرێتەوە', () {
      final engine = GameEngine();
      var r = engine.createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      s = s.copyWith(
        auction: const AuctionState(tileIndex: 3, endsAt: 999, basePrice: 60, highestBid: 50, highestBidderId: 'a'),
        phase: GamePhase.auctioning,
      );
      final bid = engine.placeBid(s, 'b', 45);
      expect(bid.isError, isTrue);
    });
  });

  group('GameEngine — پەرەوبوون و کۆتایی یاری', () {
    GameState twoPlayers({int cashA = 1500, int cashB = 1500}) {
      final r = GameEngine().createGame(board: HawlerBoard.build(), setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business'),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor'),
      ]);
      var s = r.state!;
      s = s.copyWith(players: [
        s.players[0].copyWith(cash: cashA),
        s.players[1].copyWith(cash: cashB),
      ]);
      return s;
    }

    test('کرێی زۆرتر لە دراوی یاریزان → پەرەوبوون و دیاریکردنی براوە', () {
      final engine = GameEngine();
      // B خاوەنی خانەیەکی گران، A دراوی کەمە و لەسەری دادەنیشێت.
      var s = twoPlayers(cashA: 5, cashB: 1500);
      const tileIndex = 39; // گرانترین خانە
      final tiles = Map<int, TileState>.from(s.tiles);
      tiles[tileIndex] = const TileState(tileIndex: tileIndex, ownerId: 'b', level: 3);
      s = s.copyWith(
        tiles: tiles,
        players: [s.players[0].copyWith(position: tileIndex), s.players[1]],
        phase: GamePhase.landing,
      );

      final res = engine.resolveLanding(s, 'a');
      expect(res.isOk, isTrue);
      final after = res.state!;

      final a = after.playerById('a')!;
      expect(a.bankrupt, isTrue, reason: 'یاریزانی بێ دراو دەبێت پەرەو ببێت');
      expect(a.cash, greaterThanOrEqualTo(0), reason: 'دراو نابێت ببێتە ژمارەی نەرێنی');
      expect(after.phase, GamePhase.gameOver);
      expect(after.winnerId, 'b');
    });

    test('دراوی تەواو → کرێ دەدرێت و یاری بەردەوام دەبێت', () {
      final engine = GameEngine();
      var s = twoPlayers(cashA: 1500, cashB: 1500);
      const tileIndex = 39;
      final tiles = Map<int, TileState>.from(s.tiles);
      tiles[tileIndex] = const TileState(tileIndex: tileIndex, ownerId: 'b');
      s = s.copyWith(
        tiles: tiles,
        players: [s.players[0].copyWith(position: tileIndex), s.players[1]],
        phase: GamePhase.landing,
      );

      final after = engine.resolveLanding(s, 'a').state!;
      expect(after.playerById('a')!.bankrupt, isFalse);
      expect(after.playerById('a')!.cash, lessThan(1500));
      expect(after.playerById('b')!.cash, greaterThan(1500));
      expect(after.phase, isNot(GamePhase.gameOver));
    });
  });

  group('AiBrain', () {
    test('بڕیاری کڕین بە کەسانی جیاواز', () {
      final brain = AiBrain();
      final board = HawlerBoard.build();
      var r = GameEngine().createGame(board: board, setups: const [
        PlayerSetup(id: 'a', name: 'A', characterId: 'business', kind: PlayerKind.ai, aiPersonality: AiPersonality.conservative),
        PlayerSetup(id: 'b', name: 'B', characterId: 'doctor', kind: PlayerKind.ai, aiPersonality: AiPersonality.aggressive),
      ]);
      final s = r.state!;
      final expensive = board[39]; // 400
      final aiA = s.players[0];
      // کەسی وریابین لە ٤٠٠ ناترسێت بە قورسی — دەبێت بڕیار بدات
      final buyExpensive = brain.shouldBuy(s, aiA, expensive);
      expect(buyExpensive, isFalse); // هیچ کات ناکڕێت (قورس و وریابین)
    });
  });
}
