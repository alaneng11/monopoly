import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum TileType { property, corner, chance, event, tax, station }

enum CornerKind { start, jail, freeParking, goToJail, none }

/// پێناسەی جێگیری خانەیەکی تەختە — داتای ئابووری و ناسنامەی شوێن.
@immutable
class TileDefinition {
  final int index;
  final String name;
  final TileType type;
  final CornerKind corner;
  final int group;
  final int price;
  final List<int> rentByLevel;
  final int upgradeCost;
  final int maxLevel;
  final int taxAmount;
  final int maintenance;

  const TileDefinition({
    required this.index,
    required this.name,
    this.type = TileType.property,
    this.corner = CornerKind.none,
    this.group = -1,
    this.price = 0,
    this.rentByLevel = const [],
    this.upgradeCost = 0,
    this.maxLevel = 5,
    this.taxAmount = 0,
    this.maintenance = 0,
  });

  bool get isBuyable => type == TileType.property || type == TileType.station;
  bool get isStation => type == TileType.station;

  int rentAtLevel(int level) {
    if (rentByLevel.isEmpty) return 0;
    final i = level.clamp(0, rentByLevel.length - 1);
    return rentByLevel[i];
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'name': name,
        'type': type.name,
        'group': group,
        'price': price,
      };
}

enum PlayerKind { human, ai }

enum AiDifficulty { easy, medium, hard, expert }

enum AiPersonality { balanced, investor, aggressive, conservative, riskTaker, opportunist }

/// کاراکتەرەکانی یاریزان — هەر یەکەیان ئایکۆن و ناسنامەی خۆی هەیە.
class TokenCharacter {
  final String id;
  final String name;
  final IconData icon;
  final String emoji;
  const TokenCharacter(this.id, this.name, this.icon, this.emoji);

  static const List<TokenCharacter> all = [
    TokenCharacter('business', 'بازرگان', Icons.business_center, '💼'),
    TokenCharacter('engineer', 'ئەندازیار', Icons.construction, '🛠️'),
    TokenCharacter('doctor', 'دکتۆر', Icons.medical_services, '🩺'),
    TokenCharacter('teacher', 'مامۆستا', Icons.school, '📚'),
    TokenCharacter('student', 'خوێندکار', Icons.menu_book, '🎓'),
    TokenCharacter('farmer', 'جوتیار', Icons.grass, '🌾'),
    TokenCharacter('tourist', 'گەشتیار', Icons.camera_alt, '📷'),
    TokenCharacter('mayor', 'شارەوان', Icons.account_balance, '🏛️'),
  ];

  static TokenCharacter byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.first);
}

/// دۆخی ڕاستەقینەی یاریزان لە کاتی یاریدا.
class Player {
  final String id;
  final String name;
  final int colorIndex;
  final String characterId;
  final PlayerKind kind;
  final AiDifficulty aiDifficulty;
  final AiPersonality aiPersonality;
  final int cash;
  final int position;
  final bool inJail;
  final int jailTurns;
  final int skippedTurns;
  final bool bankrupt;
  final int propertiesOwned;
  final int loansDebt;
  final int doublesInARow;

  const Player({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.characterId,
    this.kind = PlayerKind.human,
    this.aiDifficulty = AiDifficulty.medium,
    this.aiPersonality = AiPersonality.balanced,
    this.cash = 1500,
    this.position = 0,
    this.inJail = false,
    this.jailTurns = 0,
    this.skippedTurns = 0,
    this.bankrupt = false,
    this.propertiesOwned = 0,
    this.loansDebt = 0,
    this.doublesInARow = 0,
  });

  Color get color {
    const palette = [
      AppColors.emerald,
      AppColors.sapphire,
      AppColors.ruby,
      AppColors.amethyst,
      AppColors.terracotta,
      Color(0xFF2AA5A0),
    ];
    return palette[colorIndex % palette.length];
  }

  TokenCharacter get character => TokenCharacter.byId(characterId);

  bool get isAi => kind == PlayerKind.ai;

  Player copyWith({
    int? cash,
    int? position,
    bool? inJail,
    int? jailTurns,
    int? skippedTurns,
    bool? bankrupt,
    int? propertiesOwned,
    int? loansDebt,
    int? doublesInARow,
    AiDifficulty? aiDifficulty,
    AiPersonality? aiPersonality,
  }) =>
      Player(
        id: id,
        name: name,
        colorIndex: colorIndex,
        characterId: characterId,
        kind: kind,
        aiDifficulty: aiDifficulty ?? this.aiDifficulty,
        aiPersonality: aiPersonality ?? this.aiPersonality,
        cash: cash ?? this.cash,
        position: position ?? this.position,
        inJail: inJail ?? this.inJail,
        jailTurns: jailTurns ?? this.jailTurns,
        skippedTurns: skippedTurns ?? this.skippedTurns,
        bankrupt: bankrupt ?? this.bankrupt,
        propertiesOwned: propertiesOwned ?? this.propertiesOwned,
        loansDebt: loansDebt ?? this.loansDebt,
        doublesInARow: doublesInARow ?? this.doublesInARow,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'characterId': characterId,
        'kind': kind.name,
        'cash': cash,
        'position': position,
        'inJail': inJail,
        'jailTurns': jailTurns,
        'skippedTurns': skippedTurns,
        'bankrupt': bankrupt,
        'propertiesOwned': propertiesOwned,
        'loansDebt': loansDebt,
        'doubles': doublesInARow,
      };

  static Player fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: j['name'] as String,
        colorIndex: j['colorIndex'] as int? ?? 0,
        characterId: j['characterId'] as String? ?? 'business',
        kind: PlayerKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => PlayerKind.human,
        ),
        cash: j['cash'] as int? ?? 1500,
        position: j['position'] as int? ?? 0,
        inJail: j['inJail'] as bool? ?? false,
        jailTurns: j['jailTurns'] as int? ?? 0,
        skippedTurns: j['skippedTurns'] as int? ?? 0,
        bankrupt: j['bankrupt'] as bool? ?? false,
        propertiesOwned: j['propertiesOwned'] as int? ?? 0,
        loansDebt: j['loansDebt'] as int? ?? 0,
        doublesInARow: j['doubles'] as int? ?? 0,
      );
}

/// پێکهاتەی کۆگای موڵکەکان — تەواوکردنی گروپ بۆ بەخشین.
class CollectionBonus {
  final int groupId;
  final String name;
  final int bonusMoney;
  final int bonusDice;
  final int bonusXp;
  final double rentMultiplier;

  const CollectionBonus({
    required this.groupId,
    required this.name,
    this.bonusMoney = 0,
    this.bonusDice = 0,
    this.bonusXp = 0,
    this.rentMultiplier = 1.0,
  });
}

/// هەندێک گروپی موڵک بۆ کۆکەکردن.
class PropertyCollection {
  final int groupId;
  final String nameKu;
  final String descriptionKu;
  final Color groupColor;
  final int bonusCoins;
  final int bonusDice;
  final int bonusXp;
  final double rentMultiplier;

  const PropertyCollection({
    required this.groupId,
    required this.nameKu,
    required this.descriptionKu,
    required this.groupColor,
    this.bonusCoins = 200,
    this.bonusDice = 3,
    this.bonusXp = 150,
    this.rentMultiplier = 1.25,
  });

  static const List<PropertyCollection> all = [
    PropertyCollection(groupId: 0, nameKu: 'گەڕەکی قەڵات', descriptionKu: 'هەموو خانەکانی قەڵات بکڕە بۆ بەخشین', groupColor: Color(0xFF8B4A2B), bonusCoins: 200, bonusDice: 3, bonusXp: 150),
    PropertyCollection(groupId: 1, nameKu: 'بازاڕی قەیسەری', descriptionKu: 'هەموو خانەکانی بازاڕ بکڕە بۆ بەخشین', groupColor: Color(0xFF4AA3E8), bonusCoins: 300, bonusDice: 3, bonusXp: 200),
    PropertyCollection(groupId: 2, nameKu: 'پارکەکان', descriptionKu: 'هەموو پارکەکان بکڕە بۆ بەخشین', groupColor: Color(0xFFD44D6E), bonusCoins: 350, bonusDice: 4, bonusXp: 200),
    PropertyCollection(groupId: 3, nameKu: 'نەورۆز و خانزاد', descriptionKu: 'هەموو خانەکانی ئەم ڕەنگە بکڕە', groupColor: Color(0xFFE8A23A), bonusCoins: 400, bonusDice: 4, bonusXp: 250),
    PropertyCollection(groupId: 4, nameKu: 'زانیاری و ئاشتی', descriptionKu: 'هەموو خانەکانی زانیاری بکڕە', groupColor: Color(0xFFE0435A), bonusCoins: 450, bonusDice: 5, bonusXp: 280),
    PropertyCollection(groupId: 5, nameKu: 'شاری زانا و کورد', descriptionKu: 'هەموو خانەکانی زانا بکڕە', groupColor: Color(0xFFEFD24A), bonusCoins: 500, bonusDice: 5, bonusXp: 300),
    PropertyCollection(groupId: 6, nameKu: 'نیشتمان و گەشتیاری', descriptionKu: 'هەموو خانەکانی نیشتمان بکڕە', groupColor: Color(0xFF2FBF71), bonusCoins: 600, bonusDice: 6, bonusXp: 350),
    PropertyCollection(groupId: 7, nameKu: 'شاهانی و قەڵا', descriptionKu: 'هەموو خانەکانی شاهانی بکڕە', groupColor: Color(0xFF1F5C8B), bonusCoins: 800, bonusDice: 8, bonusXp: 500, rentMultiplier: 1.5),
  ];
}

/// پێشکەوتنی داواکارییەکان — ئامانج و پێشکەوتن.
class Challenge {
  final String id;
  final String titleKu;
  final String descriptionKu;
  final IconData icon;
  final int target;
  final int bonusCoins;
  final int bonusDice;
  final int bonusXp;
  final bool isWeekly;

  const Challenge({
    required this.id,
    required this.titleKu,
    required this.descriptionKu,
    required this.icon,
    required this.target,
    this.bonusCoins = 100,
    this.bonusDice = 2,
    this.bonusXp = 80,
    this.isWeekly = false,
  });

  static const List<Challenge> daily = [
    Challenge(id: 'buy_3', titleKu: 'کڕینی موڵک', descriptionKu: '٣ موڵک بکڕە', icon: Icons.shopping_bag, target: 3, bonusCoins: 150, bonusDice: 2, bonusXp: 100),
    Challenge(id: 'collect_200', titleKu: 'کۆکردنی کرێ', descriptionKu: '٢٠٠ زێڕ کۆبکە لە کرێ', icon: Icons.payments, target: 200, bonusCoins: 100, bonusDice: 2, bonusXp: 80),
    Challenge(id: 'roll_5', titleKu: 'داودانی بەرد', descriptionKu: '٥ جار بەرد بەڵێ', icon: Icons.casino, target: 5, bonusCoins: 80, bonusDice: 3, bonusXp: 60),
    Challenge(id: 'upgrade_2', titleKu: 'بەرزکردنەوە', descriptionKu: '٢ موڵک بەرز بکەرەوە', icon: Icons.arrow_upward, target: 2, bonusCoins: 200, bonusDice: 2, bonusXp: 120),
    Challenge(id: 'earn_500', titleKu: 'کۆکردنی دراو', descriptionKu: '٥٠٠ زێڕ بکە لە هەموو لایەنەکان', icon: Icons.account_balance_wallet, target: 500, bonusCoins: 120, bonusDice: 2, bonusXp: 90),
    Challenge(id: 'trade_1', titleKu: 'بازرگانی', descriptionKu: 'یەک بازرگانی تەواو بکە', icon: Icons.handshake, target: 1, bonusCoins: 180, bonusDice: 3, bonusXp: 100),
  ];

  static const List<Challenge> weekly = [
    Challenge(id: 'win_3', titleKu: 'سەرکەوتن', descriptionKu: '٣ یاری ببەرەوە', icon: Icons.emoji_events, target: 3, bonusCoins: 500, bonusDice: 8, bonusXp: 400, isWeekly: true),
    Challenge(id: 'complete_set', titleKu: 'کۆکەکردن', descriptionKu: 'یەک کۆگای موڵک تەواو بکە', icon: Icons.collections_bookmark, target: 1, bonusCoins: 600, bonusDice: 10, bonusXp: 500, isWeekly: true),
    Challenge(id: 'auction_2', titleKu: 'مزایەدە', descriptionKu: '٢ مزایەدە ببەرەوە', icon: Icons.gavel, target: 2, bonusCoins: 400, bonusDice: 6, bonusXp: 300, isWeekly: true),
    Challenge(id: 'collect_2000', titleKu: 'دەیاریی دراو', descriptionKu: '٢٠٠٠ زێڕ کۆبکە', icon: Icons.savings, target: 2000, bonusCoins: 800, bonusDice: 12, bonusXp: 600, isWeekly: true),
    Challenge(id: 'upgrade_5', titleKu: 'پەرەپێدان', descriptionKu: '٥ موڵک بەرز بکەرەوە', icon: Icons.trending_up, target: 5, bonusCoins: 700, bonusDice: 10, bonusXp: 500, isWeekly: true),
  ];
}

/// تەواوبوونی داواکاری.
class CompletedChallenge {
  final String challengeId;
  final int completedAt;
  final bool isWeekly;

  const CompletedChallenge({
    required this.challengeId,
    required this.completedAt,
    this.isWeekly = false,
  });

  Map<String, dynamic> toJson() => {
    'challengeId': challengeId,
    'completedAt': completedAt,
    'isWeekly': isWeekly,
  };

  static CompletedChallenge fromJson(Map<String, dynamic> j) => CompletedChallenge(
    challengeId: j['challengeId'] as String,
    completedAt: j['completedAt'] as int,
    isWeekly: j['isWeekly'] as bool? ?? false,
  );
}

/// تۆماری یاریی تەواوبوو.
class MatchRecord {
  final String winnerId;
  final String winnerName;
  final List<String> playerNames;
  final int round;
  final int durationSeconds;
  final int moneyEarned;
  final int propertiesOwned;
  final int tradesCompleted;
  final int auctionsWon;
  final int diceRolled;
  final int finalNetWorth;
  final DateTime playedAt;

  const MatchRecord({
    required this.winnerId,
    required this.winnerName,
    required this.playerNames,
    required this.round,
    this.durationSeconds = 0,
    this.moneyEarned = 0,
    this.propertiesOwned = 0,
    this.tradesCompleted = 0,
    this.auctionsWon = 0,
    this.diceRolled = 0,
    this.finalNetWorth = 0,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'winnerId': winnerId,
    'winnerName': winnerName,
    'playerNames': playerNames,
    'round': round,
    'durationSeconds': durationSeconds,
    'moneyEarned': moneyEarned,
    'propertiesOwned': propertiesOwned,
    'tradesCompleted': tradesCompleted,
    'auctionsWon': auctionsWon,
    'diceRolled': diceRolled,
    'finalNetWorth': finalNetWorth,
    'playedAt': playedAt.millisecondsSinceEpoch,
  };

  static MatchRecord fromJson(Map<String, dynamic> j) => MatchRecord(
    winnerId: j['winnerId'] as String? ?? '',
    winnerName: j['winnerName'] as String? ?? '',
    playerNames: (j['playerNames'] as List?)?.cast<String>() ?? [],
    round: j['round'] as int? ?? 1,
    durationSeconds: j['durationSeconds'] as int? ?? 0,
    moneyEarned: j['moneyEarned'] as int? ?? 0,
    propertiesOwned: j['propertiesOwned'] as int? ?? 0,
    tradesCompleted: j['tradesCompleted'] as int? ?? 0,
    auctionsWon: j['auctionsWon'] as int? ?? 0,
    diceRolled: j['diceRolled'] as int? ?? 0,
    finalNetWorth: j['finalNetWorth'] as int? ?? 0,
    playedAt: DateTime.fromMillisecondsSinceEpoch(j['playedAt'] as int? ?? 0),
  );
}


/// دۆخی ڕاستەقینەی خانەیەک لە یاریدا (خاوەن، ئاست، بارمتە).
class TileState {
  final int tileIndex;
  final String? ownerId;
  final int level;
  final bool mortgaged;

  const TileState({required this.tileIndex, this.ownerId, this.level = 0, this.mortgaged = false});

  TileState copyWith({String? ownerId, int? level, bool? mortgaged, bool clearOwner = false}) => TileState(
        tileIndex: tileIndex,
        ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
        level: level ?? this.level,
        mortgaged: mortgaged ?? this.mortgaged,
      );

  Map<String, dynamic> toJson() => {
        'tileIndex': tileIndex,
        'ownerId': ownerId,
        'level': level,
        'mortgaged': mortgaged,
      };

  static TileState fromJson(Map<String, dynamic> j) => TileState(
        tileIndex: j['tileIndex'] as int,
        ownerId: j['ownerId'] as String?,
        level: j['level'] as int? ?? 0,
        mortgaged: j['mortgaged'] as bool? ?? false,
      );
}

/// قۆناغەکانی سووڕانەوەی دۆخی یاری (state machine).
enum GamePhase {
  waitingForPlayers,
  startingGame,
  awaitingRoll,
  rolling,
  moving,
  landing,
  propertyDecision,
  cardEvent,
  auctioning,
  trading,
  payingRent,
  bankruptcy,
  endTurn,
  gameOver,
}

enum TransactionReason {
  purchase,
  rent,
  tax,
  reward,
  fine,
  upgrade,
  mortgageLoan,
  unmortgage,
  trade,
  loan,
  loanRepay,
  auctionWin,
  salary,
  bail,
  maintenance,
}

/// گۆڕانکارییەکی دراوی پشتڕاستکراوە.
class MoneyTransaction {
  final String fromPlayerId;
  final String toPlayerId;
  final int amount;
  final TransactionReason reason;
  final int at;

  const MoneyTransaction({
    required this.fromPlayerId,
    required this.toPlayerId,
    required this.amount,
    required this.reason,
    required this.at,
  });

  static const String bank = 'BANK';

  bool get fromBank => fromPlayerId == bank;
  bool get toBank => toPlayerId == bank;
}

/// کارتی چانس/ڕووداو لەگەڵ کاریگەری یاسایی.
enum CardEffect { gainMoney, loseMoney, moveTo, moveBy, goToJail, getOutOfJail, repairAll, collectFromAll, doubleRentNextTurn }

class GameCard {
  final String id;
  final String title;
  final String description;
  final CardEffect effect;
  final int amount;
  final int targetTileIndex;
  final bool isEvent;

  const GameCard({
    required this.id,
    required this.title,
    required this.description,
    required this.effect,
    this.amount = 0,
    this.targetTileIndex = -1,
    this.isEvent = false,
  });
}

/// ڕووداوی گشتی یاری (ئابووری، کەشوهەوا، فیستیڤاڵ...).
enum GameEventType { traffic, tourismBoom, economicCrisis, festival, construction, governmentSupport, marketChange, weather, newroz }

class ActiveGameEvent {
  final GameEventType type;
  final String name;
  final String description;
  final double rentMultiplier;
  final double priceMultiplier;
  final int endsAtTurn;
  final int? targetGroup;

  const ActiveGameEvent({
    required this.type,
    required this.name,
    required this.description,
    this.rentMultiplier = 1.0,
    this.priceMultiplier = 1.0,
    required this.endsAtTurn,
    this.targetGroup,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'description': description,
        'rentMultiplier': rentMultiplier,
        'priceMultiplier': priceMultiplier,
        'endsAtTurn': endsAtTurn,
        'targetGroup': targetGroup,
      };
}

/// دۆخی مزایەدە (auction).
class AuctionState {
  final int tileIndex;
  final int highestBid;
  final String? highestBidderId;
  final Set<String> passedBidders;
  final int endsAt;
  final int basePrice;

  const AuctionState({
    required this.tileIndex,
    this.highestBid = 0,
    this.highestBidderId,
    this.passedBidders = const {},
    required this.endsAt,
    required this.basePrice,
  });

  AuctionState copyWith({int? highestBid, String? highestBidderId, Set<String>? passedBidders, int? endsAt}) =>
      AuctionState(
        tileIndex: tileIndex,
        highestBid: highestBid ?? this.highestBid,
        highestBidderId: highestBidderId ?? this.highestBidderId,
        passedBidders: passedBidders ?? this.passedBidders,
        endsAt: endsAt ?? this.endsAt,
        basePrice: basePrice,
      );

  bool get hasBids => highestBidderId != null && highestBid > 0;
}

/// داواکاری بازرگانی نێوان دوو یاریزان.
class TradeOffer {
  final String id;
  final String fromPlayerId;
  final String toPlayerId;
  final int moneyFrom;
  final int moneyTo;
  final List<int> tilesFrom;
  final List<int> tilesTo;
  final bool acceptedByFrom;
  final bool acceptedByTo;
  final int version;

  const TradeOffer({
    required this.id,
    required this.fromPlayerId,
    required this.toPlayerId,
    this.moneyFrom = 0,
    this.moneyTo = 0,
    this.tilesFrom = const [],
    this.tilesTo = const [],
    this.acceptedByFrom = false,
    this.acceptedByTo = false,
    this.version = 1,
  });

  bool get isValid => fromPlayerId != toPlayerId && (moneyFrom > 0 || moneyTo > 0 || tilesFrom.isNotEmpty || tilesTo.isNotEmpty);

  TradeOffer copyWith({
    int? moneyFrom,
    int? moneyTo,
    List<int>? tilesFrom,
    List<int>? tilesTo,
    bool? acceptedByFrom,
    bool? acceptedByTo,
  }) =>
      TradeOffer(
        id: id,
        fromPlayerId: fromPlayerId,
        toPlayerId: toPlayerId,
        moneyFrom: moneyFrom ?? this.moneyFrom,
        moneyTo: moneyTo ?? this.moneyTo,
        tilesFrom: tilesFrom ?? this.tilesFrom,
        tilesTo: tilesTo ?? this.tilesTo,
        acceptedByFrom: acceptedByFrom ?? false,
        acceptedByTo: acceptedByTo ?? false,
        version: version + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': fromPlayerId,
        'to': toPlayerId,
        'moneyFrom': moneyFrom,
        'moneyTo': moneyTo,
        'tilesFrom': tilesFrom,
        'tilesTo': tilesTo,
        'acceptedFrom': acceptedByFrom,
        'acceptedTo': acceptedByTo,
        'version': version,
      };
}

/// هەڵەی یاسایی — هەموو ڕەتکردنەوەکان لە ئەندازەدا بەم جۆرە دەگەڕێنەوە.
class GameRuleError {
  final String messageKu;
  final String code;
  const GameRuleError(this.code, this.messageKu);

  @override
  String toString() => messageKu;
}

/// دۆخی تەواوی یاری — بێگۆڕ (immutable) بۆ سەلامەتی دۆخ.
class GameState {
  final List<TileDefinition> board;
  final List<Player> players;
  final Map<int, TileState> tiles;
  final int round;
  final int currentPlayerIndex;
  final GamePhase phase;
  final List<int> dice;
  final AuctionState? auction;
  final TradeOffer? pendingTrade;
  final ActiveGameEvent? activeEvent;
  final List<MoneyTransaction> transactions;
  final String winnerId;
  final String? lastCardId;
  final int freeCoins;
  final DateTime startedAt;
  final int seed;
  final int diceMultiplier;
  final int diceEnergy;
  final int maxDiceEnergy;
  final int energyRegenRate;
  final Map<int, CollectionBonus> completedCollections;
  final List<CompletedChallenge> completedChallenges;
  final List<MatchRecord> matchHistory;

  const GameState({
    required this.board,
    required this.players,
    required this.tiles,
    this.round = 1,
    this.currentPlayerIndex = 0,
    this.phase = GamePhase.waitingForPlayers,
    this.dice = const [1, 1],
    this.auction,
    this.pendingTrade,
    this.activeEvent,
    this.transactions = const [],
    this.winnerId = '',
    this.lastCardId,
    this.freeCoins = 0,
    required this.startedAt,
    required this.seed,
    this.diceMultiplier = 1,
    this.diceEnergy = 10,
    this.maxDiceEnergy = 10,
    this.energyRegenRate = 1,
    this.completedCollections = const {},
    this.completedChallenges = const [],
    this.matchHistory = const [],
  });

  Player? get currentPlayer => players.isEmpty ? null : players[currentPlayerIndex % players.length];

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Player> get alivePlayers => players.where((p) => !p.bankrupt).toList();

  int indexOfPlayer(String id) => players.indexWhere((p) => p.id == id);

  int ownedGroupsCount(String playerId) {
    final byGroup = <int, int>{};
    final groupSizes = <int, int>{};
    for (final t in board) {
      if (t.type == TileType.property) {
        groupSizes.update(t.group, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    for (final entry in tiles.entries) {
      final ts = entry.value;
      if (ts.ownerId == playerId && !ts.mortgaged) {
        final def = board[entry.key];
        if (def.type == TileType.property) {
          byGroup.update(def.group, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }
    var monopolies = 0;
    byGroup.forEach((g, count) {
      if (count == groupSizes[g]) monopolies++;
    });
    return monopolies;
  }

  int ownedStations(String playerId) {
    var count = 0;
    tiles.forEach((idx, ts) {
      if (ts.ownerId == playerId) {
        final def = board[idx];
        if (def.isStation && !ts.mortgaged) count++;
      }
    });
    return count;
  }

  List<TileState> playerProperties(String playerId) =>
      tiles.values.where((t) => t.ownerId == playerId).toList();

  int netWorth(String playerId) {
    final p = playerById(playerId);
    if (p == null) return 0;
    var worth = p.cash - p.loansDebt;
    for (final ts in tiles.values) {
      if (ts.ownerId != playerId) continue;
      final def = board[ts.tileIndex];
      worth += def.price;
      worth += ts.level * def.upgradeCost;
      if (ts.mortgaged) worth -= def.price ~/ 2;
    }
    return worth;
  }

  GameState copyWith({
    List<Player>? players,
    Map<int, TileState>? tiles,
    int? round,
    int? currentPlayerIndex,
    GamePhase? phase,
    List<int>? dice,
    AuctionState? auction,
    bool clearAuction = false,
    TradeOffer? pendingTrade,
    bool clearTrade = false,
    ActiveGameEvent? activeEvent,
    bool clearEvent = false,
    List<MoneyTransaction>? transactions,
    String? winnerId,
    String? lastCardId,
    bool clearLastCard = false,
    int? freeCoins,
    int? diceMultiplier,
    int? diceEnergy,
    int? maxDiceEnergy,
    int? energyRegenRate,
    Map<int, CollectionBonus>? completedCollections,
    List<CompletedChallenge>? completedChallenges,
    List<MatchRecord>? matchHistory,
  }) =>
      GameState(
        board: board,
        players: players ?? this.players,
        tiles: tiles ?? this.tiles,
        round: round ?? this.round,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        phase: phase ?? this.phase,
        dice: dice ?? this.dice,
        auction: clearAuction ? null : (auction ?? this.auction),
        pendingTrade: clearTrade ? null : (pendingTrade ?? this.pendingTrade),
        activeEvent: clearEvent ? null : (activeEvent ?? this.activeEvent),
        transactions: transactions ?? this.transactions,
        winnerId: winnerId ?? this.winnerId,
        lastCardId: clearLastCard ? null : (lastCardId ?? this.lastCardId),
        freeCoins: freeCoins ?? this.freeCoins,
        diceMultiplier: diceMultiplier ?? this.diceMultiplier,
        diceEnergy: diceEnergy ?? this.diceEnergy,
        maxDiceEnergy: maxDiceEnergy ?? this.maxDiceEnergy,
        energyRegenRate: energyRegenRate ?? this.energyRegenRate,
        completedCollections: completedCollections ?? this.completedCollections,
        completedChallenges: completedChallenges ?? this.completedChallenges,
        matchHistory: matchHistory ?? this.matchHistory,
        startedAt: startedAt,
        seed: seed,
      );
}
