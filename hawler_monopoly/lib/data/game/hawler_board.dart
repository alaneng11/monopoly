import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/game_models.dart';
import '../../features/board/board_data.dart' as ui_data;
import '../../features/board/board_data.dart' show TileData;

/// ٤٠ خانەی تەختەکە — ناوی گەڕەک و شوێنە مێژووییەکانی هەولێر.
List<TileData> buildBoardTiles() => ui_data.buildBoardTiles();

/// پێناسەی تەواوی ئابووری تەختەکە (نرخ، کرێ بەپێی ئاست، باج).
class HawlerBoard {
  HawlerBoard._();

  static const int startSalary = 200;
  static const int startCash = 1500;

  static List<TileDefinition> build() {
    const rent = {
      // [کرێ بێ ئاست, ١, ٢, ٣, ٤, ٥/شوێنی گرنگ]
      60: [4, 20, 60, 180, 320, 450],
      100: [6, 30, 90, 270, 400, 550],
      120: [8, 40, 100, 300, 450, 600],
      140: [10, 50, 150, 450, 625, 750],
      150: [12, 60, 180, 500, 700, 900],
      160: [14, 70, 200, 550, 750, 950],
      180: [16, 80, 220, 600, 800, 1000],
      200: [18, 90, 250, 700, 875, 1050],
      220: [20, 100, 300, 750, 925, 1100],
      240: [22, 110, 330, 800, 975, 1150],
      260: [24, 120, 360, 850, 1025, 1200],
      280: [26, 130, 390, 900, 1100, 1275],
      300: [28, 150, 450, 1000, 1200, 1400],
      320: [30, 160, 475, 1100, 1300, 1500],
      350: [35, 175, 500, 1200, 1400, 1700],
      400: [50, 200, 600, 1400, 1700, 2000],
    };

    TileDefinition prop(int i, String name, int group, int price, {int? upg}) => TileDefinition(
          index: i,
          name: name,
          group: group,
          price: price,
          rentByLevel: rent[price] ?? const [0],
          upgradeCost: upg ?? (price >= 300 ? 200 : price >= 180 ? 150 : 100),
          maintenance: price ~/ 20,
        );

    TileDefinition station(int i, String name) => TileDefinition(
          index: i,
          name: name,
          type: TileType.station,
          price: 200,
          rentByLevel: const [25, 50, 100, 200],
          maxLevel: 0,
        );

    return [
      const TileDefinition(index: 0, name: 'دەستپێک', type: TileType.corner, corner: CornerKind.start),
      prop(1, 'گەڕەکی قەڵات', 0, 60),
      const TileDefinition(index: 2, name: 'چانس', type: TileType.chance),
      prop(3, 'گەڕەکی شۆڕش', 0, 60),
      const TileDefinition(index: 4, name: 'باجی موڵک', type: TileType.tax, taxAmount: 100),
      station(5, 'گاراجی شار'),
      prop(6, 'بازاڕی قەیسەری', 1, 100),
      const TileDefinition(index: 7, name: 'ڕووداو', type: TileType.event),
      prop(8, 'گەڕەکی برایەتی', 1, 100),
      prop(9, 'گەڕەکی سەرچنار', 1, 120),
      const TileDefinition(index: 10, name: 'زیندان', type: TileType.corner, corner: CornerKind.jail),
      prop(11, 'پارکی شانەدەر', 2, 140),
      station(12, 'کارەبای شار'),
      prop(13, 'گەڕەکی ئازادی', 2, 140),
      prop(14, 'گەڕەکی سەلاحەدین', 2, 160),
      station(15, 'گاراجی باشوور'),
      prop(16, 'گەڕەکی نەورۆز', 3, 180),
      const TileDefinition(index: 17, name: 'چانس', type: TileType.chance),
      prop(18, 'گەڕەکی خانزاد', 3, 180),
      prop(19, 'گەڕەکی کوردستان', 3, 200),
      const TileDefinition(index: 20, name: 'پارکینگی خۆڕایی', type: TileType.corner, corner: CornerKind.freeParking),
      prop(21, 'گەڕەکی گوندی زانیاری', 4, 220),
      const TileDefinition(index: 22, name: 'ڕووداو', type: TileType.event),
      prop(23, 'گەڕەکی ئاشتی', 4, 220),
      prop(24, 'گەڕەکی زانکۆ', 4, 240),
      station(25, 'گاراجی ڕۆژهەڵات'),
      prop(26, 'گەڕەکی شاری زانا', 5, 260),
      prop(27, 'گەڕەکی گەلی کورد', 5, 260),
      station(28, 'ئاوی شار'),
      prop(29, 'گەڕەکی هەڵگورد', 5, 280),
      const TileDefinition(index: 30, name: 'بنێرە زیندان', type: TileType.corner, corner: CornerKind.goToJail),
      prop(31, 'گەڕەکی نیشتمان', 6, 300),
      prop(32, 'گەڕەکی ڕۆشنبیری', 6, 300),
      const TileDefinition(index: 33, name: 'چانس', type: TileType.chance),
      prop(34, 'گەڕەکی گەشتیاری', 6, 320),
      station(35, 'فڕۆکەخانەی هەولێر'),
      const TileDefinition(index: 36, name: 'ڕووداو', type: TileType.event),
      prop(37, 'گەڕەکی شاهانی', 7, 350),
      const TileDefinition(index: 38, name: 'باجی شکۆداری', type: TileType.tax, taxAmount: 200),
      const TileDefinition(
        index: 39,
        name: 'قەڵای هەولێر',
        group: 7,
        price: 400,
        type: TileType.property,
        rentByLevel: [50, 200, 600, 1400, 1700, 2000],
        upgradeCost: 200,
        maintenance: 20,
      ),
    ];
  }

  static Color groupColor(int group) =>
      AppColors.propertyGroups[group % AppColors.propertyGroups.length];

  static IconData? tileIcon(TileDefinition def) {
    if (def.type == TileType.station) {
      return def.name.contains('فڕۆکە') ? Icons.flight : FontAwesomeIcons.trainSubway;
    }
    switch (def.index) {
      case 0:
        return Icons.flag_circle;
      case 2:
      case 17:
      case 33:
        return Icons.help_outline;
      case 7:
      case 22:
      case 36:
        return Icons.auto_awesome;
      case 4:
      case 38:
        return Icons.receipt_long;
      case 10:
        return Icons.gavel;
      case 20:
        return Icons.local_parking;
      case 30:
        return Icons.local_police;
      case 39:
        return Icons.location_city;
      default:
        return null;
    }
  }
}

/// کارتی چانس — ١٦ کارت بە کاریگەری جیاواز.
class ChanceDeck {
  ChanceDeck._();

  static final List<GameCard> cards = [
    const GameCard(
      id: 'ch_royal',
      title: 'پاداشتی شانشین',
      description: 'دەوڵەت ٢٠٠ زێڕت دەداتێ بۆ خزمەتی شارەکەت.',
      effect: CardEffect.gainMoney,
      amount: 200,
    ),
    const GameCard(
      id: 'ch_bazaar',
      title: 'سەفەرێکی خۆش',
      description: 'بەخۆڕایی بڕۆ بۆ بازاڕی قەیسەری.',
      effect: CardEffect.moveTo,
      targetTileIndex: 6,
    ),
    const GameCard(
      id: 'ch_park',
      title: 'پیاسە لە پارک',
      description: 'بڕۆ بۆ پارکی شانەدەر و حەسانەوە وەربگرە.',
      effect: CardEffect.moveTo,
      targetTileIndex: 11,
    ),
    const GameCard(
      id: 'ch_airport',
      title: 'گەشتی فڕۆکە',
      description: 'بڕۆ بۆ فڕۆکەخانەی هەولێر.',
      effect: CardEffect.moveTo,
      targetTileIndex: 35,
    ),
    const GameCard(
      id: 'ch_tax',
      title: 'باجی گومرگ',
      description: 'دەبێت ١٠٠ زێڕ بدەیتە گومرگی شار.',
      effect: CardEffect.loseMoney,
      amount: 100,
    ),
    const GameCard(
      id: 'ch_fountain',
      title: 'کانیی گەشتیاری',
      description: 'گەشتیاران ١٥٠ زێڕیان لێبەخشی.',
      effect: CardEffect.gainMoney,
      amount: 150,
    ),
    const GameCard(
      id: 'ch_jail',
      title: 'گیرای!',
      description: 'پۆلیسی شار دەستگیری کردیت — ڕاستەوخۆ بڕۆ بۆ زیندان.',
      effect: CardEffect.goToJail,
    ),
    const GameCard(
      id: 'ch_freedom',
      title: 'ئازادی',
      description: 'بەردەنگی زیندان وەردەگریت — لە هەر کاتێکدا دەتوانیت دەرباز بیت.',
      effect: CardEffect.getOutOfJail,
    ),
    const GameCard(
      id: 'ch_repair_small',
      title: 'چاکسازی',
      description: 'بۆ هەر بینایەکت ٢٥ زێڕ بدە بۆ چاکسازی.',
      effect: CardEffect.repairAll,
      amount: 25,
    ),
    const GameCard(
      id: 'ch_birthday',
      title: 'نەورۆز پیرۆز بێت!',
      description: 'هەموو یاریزانەکان ٥٠ زێڕت پیرۆز دەکەن.',
      effect: CardEffect.collectFromAll,
      amount: 50,
    ),
    const GameCard(
      id: 'ch_market',
      title: 'داهاتی بازاڕ',
      description: 'بازاڕی قەیسەری ١٠٠ زێڕی داهاتت پێدا.',
      effect: CardEffect.gainMoney,
      amount: 100,
    ),
    const GameCard(
      id: 'ch_ticket',
      title: 'سەرپێچی هاتوچۆ',
      description: '٥ خانە بڕۆ پێشەوە.',
      effect: CardEffect.moveBy,
      amount: 5,
    ),
    const GameCard(
      id: 'ch_back',
      title: 'گەڕانەوە',
      description: '٣ خانە بڕۆ دواوە.',
      effect: CardEffect.moveBy,
      amount: -3,
    ),
    const GameCard(
      id: 'ch_start',
      title: 'گەڕانەوە بۆ دەستپێک',
      description: 'بڕۆ بۆ دەستپێک و مووچە وەربگرە.',
      effect: CardEffect.moveTo,
      targetTileIndex: 0,
    ),
    const GameCard(
      id: 'ch_fine',
      title: 'سزای ژینگە',
      description: 'شارەوانی ٧٥ زێڕ سزای دایت بۆ پیسکردنی شار.',
      effect: CardEffect.loseMoney,
      amount: 75,
    ),
    const GameCard(
      id: 'ch_tea',
      title: 'چایخانەی کوردی',
      description: 'دوای چایەکی گەرم، ٥٠ زێڕت پێدەگات.',
      effect: CardEffect.gainMoney,
      amount: 50,
    ),
  ];

  static GameCard draw(List<String> usedIds) {
    final remaining = cards.where((c) => !usedIds.contains(c.id)).toList();
    return remaining.isEmpty ? cards.first : remaining.first;
  }
}

/// کارتی ڕووداو — ڕووداوە گشتییەکانی یاری (ئابووری/کەشوهەوا/فیستیڤاڵ).
class EventDeck {
  EventDeck._();

  static final List<GameCard> cards = [
    const GameCard(
      id: 'ev_tourism',
      title: 'گەشتیاری بەرز',
      description: 'گەشتیاران هاتنە هەولێر — کرێی هەموو موڵکەکان +٥٠٪ بۆ ٢ دۆرە.',
      effect: CardEffect.gainMoney,
      amount: 0,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_crisis',
      title: 'قەیرانی ئابووری',
      description: 'نرخی موڵکەکان -٢٥٪ بۆ ٢ دۆرە.',
      effect: CardEffect.loseMoney,
      amount: 0,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_newroz',
      title: 'فیستیڤاڵی نەورۆز',
      description: 'ئاهەنگی نەورۆز! هەموو یاریزانەکان ١٠٠ زێڕ وەردەگرن.',
      effect: CardEffect.gainMoney,
      amount: 100,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_gov',
      title: 'پشتگیری حکومەت',
      description: 'حکومەت هەر خانەوادەیەک ١٥٠ زێڕ دەداتێ.',
      effect: CardEffect.gainMoney,
      amount: 150,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_weather',
      title: 'بارانی بەهێز',
      description: 'باران بارا — هەموو بیناکان پێویستیان بە ٢٠ زێڕ چاکسازییە بۆ هەر ئاستێک.',
      effect: CardEffect.repairAll,
      amount: 20,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_traffic',
      title: 'قەرەباڵغی هاتوچۆ',
      description: 'شەقامەکان قەرەباڵغن — کرێی گاراژەکان دوو ئەوەندە دەبێت بۆ ٢ دۆرە.',
      effect: CardEffect.gainMoney,
      amount: 0,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_construction',
      title: 'بونیادنان',
      description: 'شارەوانی تەرخانکردنی بونیادنان — تێچووی بەرزکردنەوە -٥٠٪ بۆ ٢ دۆرە.',
      effect: CardEffect.gainMoney,
      amount: 0,
      isEvent: true,
    ),
    const GameCard(
      id: 'ev_tea',
      title: 'گەرمی بازاڕ',
      description: 'کرێی بازاڕ و گاراژەکان +٢٥٪ بۆ ٢ دۆرە.',
      effect: CardEffect.gainMoney,
      amount: 0,
      isEvent: true,
    ),
  ];

  static GameCard draw(List<String> usedIds) {
    final remaining = cards.where((c) => !usedIds.contains(c.id)).toList();
    return remaining.isEmpty ? cards.first : remaining.first;
  }
}
