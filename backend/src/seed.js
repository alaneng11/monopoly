/**
 * Seed Data — مۆنۆپۆلی هەولێر
 *
 * Idempotent — safe to run multiple times.
 * Run with: node src/seed.js
 */

const { initDb, queryOne, run } = require('./models/database');

async function seed() {
  await initDb();

  // ── Achievements ──────────────────────────────────────────
  const achievements = [
    ['first_win', 'یەکەم سەرکەوتن', 'یەکەم یاری خۆت ببەیتەوە', '🏆', 'general', 100, 500],
    ['monopoly', 'خاوەنی گەڕەک', 'هەموو خانەکانی یەک ڕەنگ بکڕیت', '👑', 'property', 500, 2000],
    ['landmark', 'شوێنی گرنگ', 'قەڵای هەولێر بکڕیت', '🏰', 'property', 200, 1000],
    ['rich', 'زەنگین', '١٠٠٠٠ زێڕ کۆبکەیتەوە', '💰', 'economy', 300, 1500],
    ['trader', 'بازرگان', 'یەکەم بازرگانی تەواو بکەیت', '🤝', 'trade', 200, 800],
    ['auction_master', 'مە重要作用', '٥ مزایەدە ببەیتەوە', '🔨', 'trade', 300, 1200],
    ['social_butterfly', 'هاوڕێیەک', '١٠ هاوڕێ دروست بکە', '👥', 'social', 150, 600],
    ['daily_warrior', 'شەڤێ هەفتانە', '٧ ڕۆژ بەرەوپێش بگەیتەوە', '🔥', 'engagement', 400, 1600],
    ['collector', 'کۆکەر', '٢٠ کۆلێکتیف بکۆبە', '⭐', 'collection', 250, 1000],
    ['hawler_investor', 'سەرمایەگەڕی هەولێر', 'موڵکی ٥ بوار بکڕیت', '📈', 'property', 350, 1400],
  ];

  for (const [id, title, desc, icon, cat, xp, coins] of achievements) {
    const exists = await queryOne('SELECT 1 FROM achievements WHERE id = $1', [id]).catch(() => null);
    if (!exists) {
      await run(
        'INSERT INTO achievements (id, title, description, icon, category, xp_reward, coin_reward, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,0)',
        [id, title, desc, icon, cat, xp, coins]
      );
    }
  }
  console.log('✅ Achievements seeded');

  // ── Missions ──────────────────────────────────────────────
  const dailyMissions = [
    ['daily_roll_5', '٥ جار بەرد بگەیتەوە', '٥ جار بەرد بگە', 'daily', 5, 'roll', 30, 100, 1],
    ['daily_buy_2', '٢ موڵک بکڕیت', '٢ موڵک بکڕیتەوە', 'daily', 2, 'buy', 40, 150, 0],
    ['daily_upgrade_1', 'یەک موڵک بەرز بکە', 'یەک موڵک بەرز بکە', 'daily', 1, 'upgrade', 50, 200, 0],
    ['daily_rent', 'کرێ وەربگرە', 'کرێ لە یەک موڵک وەربگرە', 'daily', 1, 'collect_rent', 30, 100, 0],
    ['daily_win', 'یارییەک ببە', 'یارییەک ببەیتەوە', 'daily', 1, 'win', 80, 300, 2],
    ['daily_trade', 'بازرگانی بکە', 'یەک بازرگانی بکە', 'daily', 1, 'trade', 50, 200, 0],
  ];

  const weeklyMissions = [
    ['weekly_play_5', '٥ یاری بکە', '٥ یاری تەواو بکە', 'weekly', 5, 'games_played', 200, 800, 5],
    ['weekly_buy_10', '١٠ موڵک بکڕیت', '١٠ موڵک بکڕیتەوە', 'weekly', 10, 'buy', 300, 1000, 3],
    ['weekly_earn_5k', '٥٠٠٠ زێڕ بکەیتەوە', '٥٠٠٠ زێڕ بکەیتەوە', 'weekly', 5000, 'earn_money', 400, 1500, 5],
    ['weekly_trades_3', '٣ بازرگانی بکە', '٣ بازرگانی بکە', 'weekly', 3, 'trade', 250, 900, 2],
    ['weekly_upgrade_5', '٥ جار موڵک بەرز بکە', '٥ جار بەرز بکە', 'weekly', 5, 'upgrade', 300, 1200, 3],
  ];

  for (const [id, title, desc, period, target, action, xp, coins, dice] of [...dailyMissions, ...weeklyMissions]) {
    const exists = await queryOne('SELECT 1 FROM missions WHERE id = $1', [id]).catch(() => null);
    if (!exists) {
      await run(
        'INSERT INTO missions (id, title, description, period, target, action_type, xp_reward, coin_reward, dice_reward, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0)',
        [id, title, desc, period, target, action, xp, coins, dice]
      );
    }
  }
  console.log('✅ Missions seeded');

  // ── Daily Rewards ─────────────────────────────────────────
  const dailyRewards = [
    [1, 100, 0, 0, 0, 'رووی یەکەم'],
    [2, 150, 0, 0, 10, 'رووی دووەم'],
    [3, 200, 0, 1, 20, 'رووی سێیەم'],
    [4, 250, 1, 0, 30, 'رووی چوارەم'],
    [5, 300, 0, 2, 40, 'رووی پێنجەم'],
    [6, 400, 2, 0, 50, 'رووی شەشەم'],
    [7, 500, 5, 5, 100, 'رووی حەفتەم — بۆنیا!'],
  ];

  for (const [day, coins, gems, dice, xp, desc] of dailyRewards) {
    const exists = await queryOne('SELECT 1 FROM daily_rewards WHERE day_number = $1', [day]).catch(() => null);
    if (!exists) {
      await run(
        'INSERT INTO daily_rewards (day_number, coin_reward, gem_reward, dice_reward, xp_reward, description) VALUES ($1,$2,$3,$4,$5,$6)',
        [day, coins, gems, dice, xp, desc]
      );
    }
  }
  console.log('✅ Daily rewards seeded');

  // ── Collectibles ──────────────────────────────────────────
  const collectibles = [
    // Landmarks
    ['cl_citadel', 'قەڵای هەولێر', 'قەڵای مێژوویی هەولێر', 'landmark', 'legendary', '🏰', 'hawler_landmarks'],
    ['cl_minaret', 'minaressa هەولێر', 'بەرجی ناوداری هەولێر', 'landmark', 'epic', '🕌', 'hawler_landmarks'],
    ['cl_sami_park', 'پارکی سامی عەبدولڕەحمان', 'گەشتگا و پارک', 'landmark', 'rare', '🌳', 'hawler_landmarks'],
    ['cl_bazaar', 'بازاڕی هەولێر', 'بازاڕی کۆنی هەولێر', 'landmark', 'rare', '🏪', 'hawler_landmarks'],
    ['cl_golan', 'گولان', 'ناوچەی گولان', 'landmark', 'common', '🏘️', 'hawler_landmarks'],
    // Culture
    ['cl_kurdish_dance', 'گۆرانی کوردی', 'گۆرانی هەڵپەڕکێ', 'culture', 'rare', '💃', 'kurdish_culture'],
    ['cl_traditional_food', 'خواردنی نرخی', 'خواردنی تایبەتی هەولێر', 'culture', 'common', '🍽️', 'kurdish_culture'],
    ['cl_newroz', 'نەورۆز', 'جەژنی نەورۆز', 'culture', 'epic', '🔥', 'kurdish_culture'],
    // Food
    ['cl_kubba', 'کوبە', 'کوبەی هەولێر', 'food', 'common', '🥘', 'hawler_food'],
    ['cl_dolma', 'دۆلمە', 'دۆلمەی هەولێر', 'food', 'common', '🫔', 'hawler_food'],
    ['cl_biryani', 'بیریانی', 'بیریانی هەولێر', 'food', 'rare', '🍛', 'hawler_food'],
    // Architecture
    ['cl_chwarbakh', 'چوارباخ', 'مۆڵەکانی کۆن', 'architecture', 'rare', '🏛️', 'hawler_arch'],
    ['cl_modern', 'بینا مۆدێرن', 'بیناکانی نوێی هەولێر', 'architecture', 'common', '🏗️', 'hawler_arch'],
    // Tourism
    ['cl_eagle_sky', 'ئاسمانی هەڵپڕ', 'گەشتی ئاسمانی', 'tourism', 'epic', '🦅', 'hawler_tourism'],
    ['cl_sheikh_shariar', 'شێخ شاڕێر', 'پارکی شێخ شاڕێر', 'tourism', 'common', '🌸', 'hawler_tourism'],
  ];

  for (const [id, title, desc, cat, rarity, icon, set_id] of collectibles) {
    const exists = await queryOne('SELECT 1 FROM collectibles WHERE id = $1', [id]).catch(() => null);
    if (!exists) {
      await run(
        'INSERT INTO collectibles (id, title, description, category, rarity, icon, set_id) VALUES ($1,$2,$3,$4,$5,$6,$7)',
        [id, title, desc, cat, rarity, icon, set_id]
      );
    }
  }
  console.log('✅ Collectibles seeded');

  console.log('\n🎉 All seed data complete!');
  process.exit(0);
}

seed().catch(e => { console.error('❌ Seed failed:', e.message); process.exit(1); });
