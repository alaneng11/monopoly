import 'dart:math' as math;

import '../data/game/hawler_board.dart';
import 'models/game_models.dart';

/// مێشکی AI — بڕیاری ستراتیژی دەدات بەپێی ئاست و کەسایەتی.
class AiBrain {
  final math.Random random;
  AiBrain({math.Random? random}) : random = random ?? math.Random();

  /// بڕیار دەدات ئایا خانەکە بکڕێت.
  bool shouldBuy(GameState state, Player ai, TileDefinition tile) {
    if (ai.cash < HawlerBoard.startCash * 0.35) return false;
    final price = tile.price;
    final cashRatio = ai.cash / math.max(1, price);

    var score = 0.5;
    // بەهای خانە بەرامبەر دراو
    if (cashRatio > 4) score += 0.15;
    if (cashRatio < 1.6) score -= 0.2;
    // هەبوونی هەمان گروپ
    final sameGroupOwned = state.board.where((t) => t.group == tile.group && state.tiles[t.index]?.ownerId == ai.id).length;
    score += sameGroupOwned * 0.18;
    // شوێنی گرنگ (قەڵا)
    if (tile.price >= 350) score -= 0.08;

    // کەسایەتی
    switch (ai.aiPersonality) {
      case AiPersonality.aggressive:
        score += 0.15;
      case AiPersonality.investor:
        score += 0.12;
        if (tile.price >= 260) score += 0.08;
      case AiPersonality.conservative:
        score -= 0.18;
        if (ai.cash < price * 2.2) score -= 0.15;
      case AiPersonality.riskTaker:
        score += 0.2;
      case AiPersonality.opportunist:
        final rivals = state.alivePlayers.where((p) => p.id != ai.id);
        for (final r in rivals) {
          final rivalSame = state.board.where((t) => t.group == tile.group && state.tiles[t.index]?.ownerId == r.id).length;
          if (rivalSame >= 1) score += 0.12; // بلۆککردنی ڕکابەر
        }
      case AiPersonality.balanced:
        break;
    }

    // ئاستی قورسی
    final threshold = switch (ai.aiDifficulty) {
      AiDifficulty.easy => 0.72,
      AiDifficulty.medium => 0.58,
      AiDifficulty.hard => 0.48,
      AiDifficulty.expert => 0.4,
    };

    return score >= threshold;
  }

  /// بڕیاری بەرزکردنەوە — لێژنەی خانەکان هەڵدەبژێرێت.
  int? chooseUpgrade(GameState state, Player ai) {
    final owned = state.tiles.values.where((t) => t.ownerId == ai.id).toList();
    for (final ts in owned) {
      final def = state.board[ts.tileIndex];
      if (def.isStation || ts.mortgaged) continue;
      if (ts.level >= def.maxLevel) continue;
      final cost = def.upgradeCost;
      final reserve = switch (ai.aiDifficulty) {
        AiDifficulty.easy => 0.2,
        AiDifficulty.medium => 0.4,
        AiDifficulty.hard => 0.55,
        AiDifficulty.expert => 0.7,
      };
      if (ai.cash < cost + HawlerBoard.startCash * reserve) continue;
      // تەنها لە گروپی تەواو بەرز بکەرەوە
      var groupTotal = 0;
      var groupOwned = 0;
      for (final t in state.board) {
        if (t.type != TileType.property || t.group != def.group) continue;
        groupTotal++;
        if (state.tiles[t.index]?.ownerId == ai.id) groupOwned++;
      }
      if (groupTotal == 0 || groupOwned < groupTotal) continue;
      return ts.tileIndex;
    }
    return null;
  }

  /// کەمترین ئاستی دراو بۆ بارمتەکردن.
  int? chooseMortgage(GameState state, Player ai, int needed) {
    if (ai.cash >= needed) return null;
    final candidates = state.tiles.values
        .where((t) => t.ownerId == ai.id && !t.mortgaged && t.level == 0)
        .toList()
      ..sort((a, b) => state.board[a.tileIndex].price.compareTo(state.board[b.tileIndex].price));
    return candidates.isEmpty ? null : candidates.first.tileIndex;
  }

  /// بڕیاری مزایەدە.
  int bidAmount(GameState state, Player ai, AuctionState auction) {
    final def = state.board[auction.tileIndex];
    if (ai.cash < auction.highestBid + 10) return -1; // pass
    final value = def.price * _demandFactor(state, def);
    final aggressiveBoost = ai.aiPersonality == AiPersonality.aggressive ? 1.1 : 1.0;
    final limit = math.min(value * aggressiveBoost, def.price);
    final nextBid = auction.highestBid + math.max(10, auction.highestBid ~/ 10);
    if (nextBid > limit || nextBid > ai.cash * 0.8) return -1;
    return nextBid.round();
  }

  double _demandFactor(GameState state, TileDefinition def) {
    var f = 0.8;
    final rivals = state.alivePlayers.length - 1;
    f += rivals * 0.04;
    return f;
  }

  /// پێشنیاری بازرگانی: خانەی ڕکابەر دەوێت بۆ تەواوکردنی گروپ.
  TradeOffer? proposeTrade(GameState state, Player ai) {
    if (ai.cash < 300) return null;
    for (final def in state.board) {
      if (def.type != TileType.property) continue;
      final myCount = state.board.where((t) => t.group == def.group && state.tiles[t.index]?.ownerId == ai.id).length;
      if (myCount < 1) continue;
      final ownerTs = state.tiles[def.index];
      if (ownerTs == null || ownerTs.ownerId == ai.id) continue;
      final owner = state.playerById(ownerTs.ownerId!);
      if (owner == null || owner.bankrupt) continue;
      final offerPrice = math.min((def.price * 0.7).round(), ai.cash ~/ 2);
      if (offerPrice < 60) continue;
      final chance = switch (ai.aiDifficulty) {
        AiDifficulty.easy => 0.05,
        AiDifficulty.medium => 0.12,
        AiDifficulty.hard => 0.2,
        AiDifficulty.expert => 0.3,
      };
      if (random.nextDouble() > chance) continue;
      return TradeOffer(
        id: 't_${DateTime.now().millisecondsSinceEpoch}_${ai.id}',
        fromPlayerId: ai.id,
        toPlayerId: owner.id,
        moneyFrom: offerPrice,
        tilesTo: [def.index],
      );
    }
    return null;
  }

  /// ئایا پێشنیازی بازرگانی قبوڵ بکات.
  bool acceptTrade(GameState state, TradeOffer offer, Player ai) {
    final gained = offer.moneyTo + offer.tilesTo.fold(0, (a, i) => a + state.board[i].price);
    final lost = offer.moneyFrom + offer.tilesFrom.fold(0, (a, i) => a + state.board[i].price);
    final margin = (gained - lost).abs() < 40;
    final net = gained - lost;
    final greed = switch (ai.aiPersonality) {
      AiPersonality.aggressive => 0.0,
      AiPersonality.conservative => 0.15,
      AiPersonality.investor => 0.05,
      _ => 0.1,
    };
    return net >= 0 && (net > lost * greed || margin && net >= 0);
  }

  /// بڕیاری زیندان: پارە بدات یان چاوەڕوان بکات.
  bool payBail(GameState state, Player ai) {
    if (ai.cash > bailCostStatic * 4) return true;
    if (ai.jailTurns >= 2) return ai.cash >= bailCostStatic;
    return ai.aiDifficulty == AiDifficulty.expert && ai.cash >= bailCostStatic * 2;
  }

  static const int bailCostStatic = 50;
}
