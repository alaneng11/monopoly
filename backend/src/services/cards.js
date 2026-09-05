/**
 * Card Decks — مۆنۆپۆلی هەولێر
 *
 * Server-side mirror of the Dart decks in
 * `hawler_monopoly/lib/data/game/hawler_board.dart` (ChanceDeck / EventDeck).
 * IDs, titles and effects MUST stay in sync with that file so the client can
 * render the drawn card without a second source of truth.
 */

// effect: gainMoney | loseMoney | moveTo | moveBy | goToJail | getOutOfJail
//       | repairAll | collectFromAll

const CHANCE_CARDS = [
  { id: 'ch_royal', title: 'پاداشتی شانشین', description: 'دەوڵەت ٢٠٠ زێڕت دەداتێ بۆ خزمەتی شارەکەت.', effect: 'gainMoney', amount: 200 },
  { id: 'ch_bazaar', title: 'سەفەرێکی خۆش', description: 'بەخۆڕایی بڕۆ بۆ بازاڕی قەیسەری.', effect: 'moveTo', targetTileIndex: 6 },
  { id: 'ch_park', title: 'پیاسە لە پارک', description: 'بڕۆ بۆ پارکی شانەدەر و حەسانەوە وەربگرە.', effect: 'moveTo', targetTileIndex: 11 },
  { id: 'ch_airport', title: 'گەشتی فڕۆکە', description: 'بڕۆ بۆ فڕۆکەخانەی هەولێر.', effect: 'moveTo', targetTileIndex: 35 },
  { id: 'ch_tax', title: 'باجی گومرگ', description: 'دەبێت ١٠٠ زێڕ بدەیتە گومرگی شار.', effect: 'loseMoney', amount: 100 },
  { id: 'ch_fountain', title: 'کانیی گەشتیاری', description: 'گەشتیاران ١٥٠ زێڕیان لێبەخشی.', effect: 'gainMoney', amount: 150 },
  { id: 'ch_jail', title: 'گیرای!', description: 'پۆلیسی شار دەستگیری کردیت — ڕاستەوخۆ بڕۆ بۆ زیندان.', effect: 'goToJail' },
  { id: 'ch_freedom', title: 'ئازادی', description: 'بەردەنگی زیندان وەردەگریت — لە هەر کاتێکدا دەتوانیت دەرباز بیت.', effect: 'getOutOfJail' },
  { id: 'ch_repair_small', title: 'چاکسازی', description: 'بۆ هەر بینایەکت ٢٥ زێڕ بدە بۆ چاکسازی.', effect: 'repairAll', amount: 25 },
  { id: 'ch_birthday', title: 'نەورۆز پیرۆز بێت!', description: 'هەموو یاریزانەکان ٥٠ زێڕت پیرۆز دەکەن.', effect: 'collectFromAll', amount: 50 },
  { id: 'ch_market', title: 'داهاتی بازاڕ', description: 'بازاڕی قەیسەری ١٠٠ زێڕی داهاتت پێدا.', effect: 'gainMoney', amount: 100 },
  { id: 'ch_ticket', title: 'سەرپێچی هاتوچۆ', description: '٥ خانە بڕۆ پێشەوە.', effect: 'moveBy', amount: 5 },
  { id: 'ch_back', title: 'گەڕانەوە', description: '٣ خانە بڕۆ دواوە.', effect: 'moveBy', amount: -3 },
  { id: 'ch_start', title: 'گەڕانەوە بۆ دەستپێک', description: 'بڕۆ بۆ دەستپێک و مووچە وەربگرە.', effect: 'moveTo', targetTileIndex: 0 },
  { id: 'ch_fine', title: 'سزای ژینگە', description: 'شارەوانی ٧٥ زێڕ سزای دایت بۆ پیسکردنی شار.', effect: 'loseMoney', amount: 75 },
  { id: 'ch_tea', title: 'چایخانەی کوردی', description: 'دوای چایەکی گەرم، ٥٠ زێڕت پێدەگات.', effect: 'gainMoney', amount: 50 },
];

const EVENT_CARDS = [
  { id: 'ev_tourism', title: 'گەشتیاری بەرز', description: 'گەشتیاران هاتنە هەولێر — کرێی هەموو موڵکەکان +٥٠٪ بۆ ٢ دۆرە.', effect: 'gainMoney', amount: 0, isEvent: true },
  { id: 'ev_crisis', title: 'قەیرانی ئابووری', description: 'نرخی موڵکەکان -٢٥٪ بۆ ٢ دۆرە.', effect: 'loseMoney', amount: 0, isEvent: true },
  { id: 'ev_newroz', title: 'فیستیڤاڵی نەورۆز', description: 'ئاهەنگی نەورۆز! هەموو یاریزانەکان ١٠٠ زێڕ وەردەگرن.', effect: 'gainMoney', amount: 100, isEvent: true },
  { id: 'ev_gov', title: 'پشتگیری حکومەت', description: 'حکومەت هەر خانەوادەیەک ١٥٠ زێڕ دەداتێ.', effect: 'gainMoney', amount: 150, isEvent: true },
  { id: 'ev_weather', title: 'بارانی بەهێز', description: 'باران بارا — هەموو بیناکان پێویستیان بە ٢٠ زێڕ چاکسازییە بۆ هەر ئاستێک.', effect: 'repairAll', amount: 20, isEvent: true },
  { id: 'ev_traffic', title: 'قەرەباڵغی هاتوچۆ', description: 'شەقامەکان قەرەباڵغن — کرێی گاراژەکان دوو ئەوەندە دەبێت بۆ ٢ دۆرە.', effect: 'gainMoney', amount: 0, isEvent: true },
  { id: 'ev_construction', title: 'بونیادنان', description: 'شارەوانی تەرخانکردنی بونیادنان — تێچووی بەرزکردنەوە -٥٠٪ بۆ ٢ دۆرە.', effect: 'gainMoney', amount: 0, isEvent: true },
  { id: 'ev_tea', title: 'گەرمی بازاڕ', description: 'کرێی بازاڕ و گاراژەکان +٢٥٪ بۆ ٢ دۆرە.', effect: 'gainMoney', amount: 0, isEvent: true },
];

/** Pick a card at random from the deck matching `type` ('chance' | 'event'). */
function drawCard(type) {
  const deck = type === 'event' ? EVENT_CARDS : CHANCE_CARDS;
  const card = deck[Math.floor(Math.random() * deck.length)];
  return { amount: 0, targetTileIndex: -1, isEvent: type === 'event', ...card };
}

module.exports = { CHANCE_CARDS, EVENT_CARDS, drawCard };
