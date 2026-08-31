/**
 * Auto Setup — مۆنۆپۆلی هەولێر
 * 
 * Runs migrations + seed data on server startup.
 * Does NOT call process.exit().
 */

const { initDb, query, queryOne, run, USE_PG } = require('./models/database');

const UP = `
-- 1. USERS & AUTH
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT 'یاریزان',
  email TEXT,
  password_hash TEXT,
  avatar_url TEXT,
  coins INTEGER NOT NULL DEFAULT 3000,
  gems INTEGER NOT NULL DEFAULT 20,
  xp INTEGER NOT NULL DEFAULT 0,
  level INTEGER NOT NULL DEFAULT 1,
  wins INTEGER NOT NULL DEFAULT 0,
  games_played INTEGER NOT NULL DEFAULT 0,
  streak INTEGER NOT NULL DEFAULT 0,
  last_login_at BIGINT,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 2. PLAYER PROFILES
CREATE TABLE IF NOT EXISTS player_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  title TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  selected_avatar TEXT DEFAULT 'business',
  selected_title TEXT DEFAULT '',
  cosmetics JSONB DEFAULT '{}',
  stats JSONB DEFAULT '{}'
);

-- 3. GAME ROOMS
CREATE TABLE IF NOT EXISTS game_rooms (
  code TEXT PRIMARY KEY,
  host_id TEXT NOT NULL REFERENCES users(id),
  room_name TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'lobby',
  max_players INTEGER NOT NULL DEFAULT 6,
  is_public INTEGER NOT NULL DEFAULT 0,
  start_cash INTEGER NOT NULL DEFAULT 1500,
  version INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  started_at BIGINT,
  finished_at BIGINT
);

-- 4. GAME ROOM PLAYERS
CREATE TABLE IF NOT EXISTS game_room_players (
  room_code TEXT NOT NULL REFERENCES game_rooms(code) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id),
  character_id TEXT NOT NULL DEFAULT 'business',
  seat INTEGER NOT NULL DEFAULT 0,
  ready INTEGER NOT NULL DEFAULT 0,
  connected INTEGER NOT NULL DEFAULT 1,
  joined_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (room_code, user_id)
);

-- 5. GAME STATE (Server-Authoritative)
CREATE TABLE IF NOT EXISTS game_states (
  room_code TEXT PRIMARY KEY REFERENCES game_rooms(code) ON DELETE CASCADE,
  round INTEGER NOT NULL DEFAULT 1,
  current_player_index INTEGER NOT NULL DEFAULT 0,
  phase TEXT NOT NULL DEFAULT 'awaitingRoll',
  dice TEXT NOT NULL DEFAULT '[1,1]',
  players JSONB NOT NULL DEFAULT '[]',
  tiles JSONB NOT NULL DEFAULT '{}',
  free_coins INTEGER NOT NULL DEFAULT 0,
  winner_id TEXT DEFAULT '',
  seed INTEGER NOT NULL DEFAULT 0,
  dice_multiplier INTEGER NOT NULL DEFAULT 1,
  dice_energy INTEGER NOT NULL DEFAULT 10,
  max_dice_energy INTEGER NOT NULL DEFAULT 10,
  energy_regen_rate INTEGER NOT NULL DEFAULT 1,
  turn_token INTEGER NOT NULL DEFAULT 0,
  active_event JSONB,
  pending_trade JSONB,
  auction JSONB,
  state_version INTEGER NOT NULL DEFAULT 1,
  turn_started_at BIGINT,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 6. PROPERTIES
CREATE TABLE IF NOT EXISTS properties (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL REFERENCES game_rooms(code) ON DELETE CASCADE,
  tile_index INTEGER NOT NULL,
  owner_id TEXT REFERENCES users(id),
  level INTEGER NOT NULL DEFAULT 0,
  mortgaged INTEGER NOT NULL DEFAULT 0,
  UNIQUE(room_code, tile_index)
);

-- 7. TRANSACTIONS
CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  room_code TEXT,
  from_id TEXT NOT NULL,
  to_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  metadata JSONB DEFAULT '{}',
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_tx_room ON transactions(room_code, created_at);
CREATE INDEX IF NOT EXISTS idx_tx_from ON transactions(from_id, created_at);
CREATE INDEX IF NOT EXISTS idx_tx_to ON transactions(to_id, created_at);

-- 8. TRADES
CREATE TABLE IF NOT EXISTS trades (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL,
  from_user TEXT NOT NULL REFERENCES users(id),
  to_user TEXT NOT NULL REFERENCES users(id),
  money_from INTEGER NOT NULL DEFAULT 0,
  money_to INTEGER NOT NULL DEFAULT 0,
  tiles_from JSONB DEFAULT '[]',
  tiles_to JSONB DEFAULT '[]',
  cards_from JSONB DEFAULT '[]',
  cards_to JSONB DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'pending',
  accepted_by_from INTEGER NOT NULL DEFAULT 0,
  accepted_by_to INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  resolved_at BIGINT
);

-- 9. AUCTIONS
CREATE TABLE IF NOT EXISTS auctions (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL,
  tile_index INTEGER NOT NULL,
  highest_bid INTEGER NOT NULL DEFAULT 0,
  highest_bidder TEXT,
  base_price INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  started_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  ends_at BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS auction_bids (
  id SERIAL PRIMARY KEY,
  auction_id INTEGER NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
  bidder_id TEXT NOT NULL REFERENCES users(id),
  amount INTEGER NOT NULL,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 10. GAME CHAT
CREATE TABLE IF NOT EXISTS game_chat_messages (
  id TEXT PRIMARY KEY,
  game_room_id TEXT NOT NULL,
  sender_id TEXT NOT NULL REFERENCES users(id),
  sender_name TEXT NOT NULL DEFAULT '',
  text TEXT NOT NULL DEFAULT '',
  emoji TEXT,
  is_emoji INTEGER NOT NULL DEFAULT 0,
  message_type TEXT NOT NULL DEFAULT 'text',
  timestamp BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_game_chat_room ON game_chat_messages(game_room_id, timestamp);

-- 11. FRIEND CHAT
CREATE TABLE IF NOT EXISTS friend_chat_messages (
  id TEXT PRIMARY KEY,
  chat_id TEXT NOT NULL,
  sender_id TEXT NOT NULL REFERENCES users(id),
  receiver_id TEXT NOT NULL REFERENCES users(id),
  text TEXT NOT NULL DEFAULT '',
  emoji TEXT,
  is_emoji INTEGER NOT NULL DEFAULT 0,
  message_type TEXT NOT NULL DEFAULT 'text',
  read INTEGER NOT NULL DEFAULT 0,
  timestamp BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_friend_chat ON friend_chat_messages(chat_id, timestamp);

-- 12. FRIENDSHIPS
CREATE TABLE IF NOT EXISTS friendships (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  accepted_at BIGINT,
  PRIMARY KEY (user_id, friend_id)
);

-- 13. ACHIEVEMENTS
CREATE TABLE IF NOT EXISTS achievements (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT DEFAULT '',
  category TEXT DEFAULT 'general',
  xp_reward INTEGER NOT NULL DEFAULT 100,
  coin_reward INTEGER NOT NULL DEFAULT 500,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_achievements (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES achievements(id),
  unlocked_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (user_id, achievement_id)
);

-- 14. MISSIONS / CHALLENGES
CREATE TABLE IF NOT EXISTS missions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  period TEXT NOT NULL DEFAULT 'daily',
  target INTEGER NOT NULL DEFAULT 1,
  action_type TEXT NOT NULL,
  xp_reward INTEGER NOT NULL DEFAULT 50,
  coin_reward INTEGER NOT NULL DEFAULT 200,
  dice_reward INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_missions (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  mission_id TEXT NOT NULL REFERENCES missions(id),
  progress INTEGER NOT NULL DEFAULT 0,
  completed INTEGER NOT NULL DEFAULT 0,
  claimed INTEGER NOT NULL DEFAULT 0,
  period_start BIGINT NOT NULL,
  completed_at BIGINT,
  PRIMARY KEY (user_id, mission_id, period_start)
);

-- 15. DAILY REWARDS
CREATE TABLE IF NOT EXISTS daily_rewards (
  id SERIAL PRIMARY KEY,
  day_number INTEGER NOT NULL,
  coin_reward INTEGER NOT NULL DEFAULT 100,
  gem_reward INTEGER NOT NULL DEFAULT 0,
  dice_reward INTEGER NOT NULL DEFAULT 0,
  xp_reward INTEGER NOT NULL DEFAULT 0,
  description TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS user_daily_rewards (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day_number INTEGER NOT NULL,
  claimed_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  streak INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (user_id, day_number)
);

-- 16. COLLECTIBLES
CREATE TABLE IF NOT EXISTS collectibles (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  rarity TEXT NOT NULL DEFAULT 'common',
  icon TEXT DEFAULT '',
  set_id TEXT
);

CREATE TABLE IF NOT EXISTS user_collectibles (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  collectible_id TEXT NOT NULL REFERENCES collectibles(id),
  acquired_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (user_id, collectible_id)
);

-- 17. MATCH HISTORY
CREATE TABLE IF NOT EXISTS match_history (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL,
  winner_id TEXT REFERENCES users(id),
  winner_name TEXT NOT NULL DEFAULT '',
  player_ids JSONB NOT NULL DEFAULT '[]',
  player_names JSONB NOT NULL DEFAULT '[]',
  round INTEGER NOT NULL DEFAULT 0,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  final_net_worth INTEGER NOT NULL DEFAULT 0,
  stats JSONB DEFAULT '{}',
  played_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_match_winner ON match_history(winner_id);
CREATE INDEX IF NOT EXISTS idx_match_played ON match_history(played_at DESC);

-- 18. LEADERBOARD
CREATE TABLE IF NOT EXISTS leaderboard (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  weekly_xp INTEGER NOT NULL DEFAULT 0,
  monthly_xp INTEGER NOT NULL DEFAULT 0,
  total_xp INTEGER NOT NULL DEFAULT 0,
  weekly_wins INTEGER NOT NULL DEFAULT 0,
  monthly_wins INTEGER NOT NULL DEFAULT 0,
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 19. PLAYER STATISTICS
CREATE TABLE IF NOT EXISTS player_statistics (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  games_played INTEGER NOT NULL DEFAULT 0,
  games_won INTEGER NOT NULL DEFAULT 0,
  games_lost INTEGER NOT NULL DEFAULT 0,
  total_money_earned INTEGER NOT NULL DEFAULT 0,
  total_money_spent INTEGER NOT NULL DEFAULT 0,
  properties_purchased INTEGER NOT NULL DEFAULT 0,
  properties_sold INTEGER NOT NULL DEFAULT 0,
  rent_collected INTEGER NOT NULL DEFAULT 0,
  trades_completed INTEGER NOT NULL DEFAULT 0,
  auctions_won INTEGER NOT NULL DEFAULT 0,
  dice_rolled INTEGER NOT NULL DEFAULT 0,
  total_play_time_seconds INTEGER NOT NULL DEFAULT 0,
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 20. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  data JSONB DEFAULT '{}',
  read INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, read, created_at DESC);

-- 21. GAME EVENTS
CREATE TABLE IF NOT EXISTS game_events (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL,
  event_type TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  rent_multiplier REAL DEFAULT 1.0,
  price_multiplier REAL DEFAULT 1.0,
  ends_at_round INTEGER NOT NULL,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 22. USER SESSIONS
CREATE TABLE IF NOT EXISTS user_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_code TEXT,
  ws_id TEXT,
  last_active BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_session_user ON user_sessions(user_id);

-- 23. SEASONS
CREATE TABLE IF NOT EXISTS seasons (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  start_date BIGINT NOT NULL,
  end_date BIGINT NOT NULL,
  max_tier INTEGER NOT NULL DEFAULT 30,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

CREATE TABLE IF NOT EXISTS user_seasons (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  season_id TEXT NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
  current_tier INTEGER NOT NULL DEFAULT 1,
  season_xp INTEGER NOT NULL DEFAULT 0,
  claimed_tiers JSONB DEFAULT '[]',
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (user_id, season_id)
);

-- 24. COSMETICS & INVENTORY
CREATE TABLE IF NOT EXISTS cosmetics (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL,
  rarity TEXT NOT NULL DEFAULT 'common',
  coin_price INTEGER NOT NULL DEFAULT 0,
  gem_price INTEGER NOT NULL DEFAULT 0,
  icon TEXT DEFAULT '',
  preview_asset TEXT DEFAULT '',
  is_for_sale INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS user_cosmetics (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cosmetic_id TEXT NOT NULL REFERENCES cosmetics(id) ON DELETE CASCADE,
  is_equipped INTEGER NOT NULL DEFAULT 0,
  acquired_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (user_id, cosmetic_id)
);
CREATE INDEX IF NOT EXISTS idx_user_cosmetics ON user_cosmetics(user_id, is_equipped);

-- 25. BANK LOANS
CREATE TABLE IF NOT EXISTS bank_loans (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id),
  principal INTEGER NOT NULL,
  interest_rate REAL NOT NULL DEFAULT 0.10,
  amount_due INTEGER NOT NULL,
  due_round INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- 26. SPECTATORS
CREATE TABLE IF NOT EXISTS spectators (
  room_code TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id),
  joined_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  PRIMARY KEY (room_code, user_id)
);
`;

// SQLite-specific adaptations
const UP_SQLITE = UP
  .replace(/DEFAULT \(extract\(epoch from now\(\)\)::bigint\)/g, 'DEFAULT (unixepoch())')
  .replace(/SERIAL PRIMARY KEY/g, 'INTEGER PRIMARY KEY AUTOINCREMENT')
  .replace(/JSONB/g, 'TEXT')
  .replace(/REAL DEFAULT/g, 'REAL DEFAULT');

async function autoSetup() {
  await initDb();

  // Check if tables exist
  let tableCheck;
  if (USE_PG) {
    tableCheck = await queryOne("SELECT COUNT(*) as c FROM information_schema.tables WHERE table_schema = 'public'").catch(() => null);
  } else {
    tableCheck = await queryOne("SELECT COUNT(*) as c FROM sqlite_master WHERE type='table' AND name='users'").catch(() => null);
  }

  const tablesExist = tableCheck && (
    USE_PG ? parseInt(tableCheck.c) > 0 : parseInt(tableCheck.c) === 1
  );

  if (!tablesExist) {
    console.log('🔄 Running migrations...');
    const sql = USE_PG ? UP : UP_SQLITE;
    const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);
    let count = 0;
    for (const stmt of statements) {
      try {
        await run(stmt);
        count++;
      } catch (e) {
        if (!e.message?.includes('already exists')) {
          console.error(`  ⚠️ ${e.message}`);
        }
      }
    }
    console.log(`✅ Migrations done: ${count} statements`);
  }

  // Seed achievements if empty
  const achCount = await queryOne('SELECT COUNT(*) as c FROM achievements').catch(() => null);
  if (achCount && parseInt(achCount.c) === 0) {
    console.log('🌱 Seeding achievements...');
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
      try {
        await run('INSERT INTO achievements (id, title, description, icon, category, xp_reward, coin_reward, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,0)', [id, title, desc, icon, cat, xp, coins]);
      } catch (_) {}
    }
    console.log('✅ Achievements seeded');
  }

  // Seed missions if empty
  const missCount = await queryOne('SELECT COUNT(*) as c FROM missions').catch(() => null);
  if (missCount && parseInt(missCount.c) === 0) {
    console.log('🌱 Seeding missions...');
    const missions = [
      ['daily_roll_5', '٥ جار بەرد بگەیتەوە', 'daily', 5, 'roll', 30, 100, 1],
      ['daily_buy_2', '٢ موڵک بکڕیت', 'daily', 2, 'buy', 40, 150, 0],
      ['daily_upgrade_1', 'یەک موڵک بەرز بکە', 'daily', 1, 'upgrade', 50, 200, 0],
      ['daily_rent', 'کرێ وەربگرە', 'daily', 1, 'collect_rent', 30, 100, 0],
      ['daily_win', 'یارییەک ببە', 'daily', 1, 'win', 80, 300, 2],
      ['daily_trade', 'بازرگانی بکە', 'daily', 1, 'trade', 50, 200, 0],
      ['weekly_play_5', '٥ یاری بکە', 'weekly', 5, 'games_played', 200, 800, 5],
      ['weekly_buy_10', '١٠ موڵک بکڕیت', 'weekly', 10, 'buy', 300, 1000, 3],
      ['weekly_earn_5k', '٥٠٠٠ زێڕ بکەیتەوە', 'weekly', 5000, 'earn_money', 400, 1500, 5],
      ['weekly_trades_3', '٣ بازرگانی بکە', 'weekly', 3, 'trade', 250, 900, 2],
      ['weekly_upgrade_5', '٥ جار موڵک بەرز بکە', 'weekly', 5, 'upgrade', 300, 1200, 3],
    ];
    for (const [id, title, desc, period, target, action, xp, coins, dice] of missions) {
      try {
        await run('INSERT INTO missions (id, title, description, period, target, action_type, xp_reward, coin_reward, dice_reward, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0)', [id, title, desc, period, target, action, xp, coins, dice]);
      } catch (_) {}
    }
    console.log('✅ Missions seeded');
  }

  // Seed daily rewards if empty
  const drCount = await queryOne('SELECT COUNT(*) as c FROM daily_rewards').catch(() => null);
  if (drCount && parseInt(drCount.c) === 0) {
    console.log('🌱 Seeding daily rewards...');
    const rewards = [
      [1, 100, 0, 0, 0, 'رووی یەکەم'], [2, 150, 0, 0, 10, 'رووی دووەم'],
      [3, 200, 0, 1, 20, 'رووی سێیەم'], [4, 250, 1, 0, 30, 'رووی چوارەم'],
      [5, 300, 0, 2, 40, 'رووی پێنجەم'], [6, 400, 2, 0, 50, 'رووی شەشەم'],
      [7, 500, 5, 5, 100, 'رووی حەفتەم — بۆنیا!'],
    ];
    for (const [day, coins, gems, dice, xp, desc] of rewards) {
      try {
        await run('INSERT INTO daily_rewards (day_number, coin_reward, gem_reward, dice_reward, xp_reward, description) VALUES ($1,$2,$3,$4,$5,$6)', [day, coins, gems, dice, xp, desc]);
      } catch (_) {}
    }
    console.log('✅ Daily rewards seeded');
  }

  // Seed collectibles if empty
  const clCount = await queryOne('SELECT COUNT(*) as c FROM collectibles').catch(() => null);
  if (clCount && parseInt(clCount.c) === 0) {
    console.log('🌱 Seeding collectibles...');
    const collectibles = [
      ['cl_citadel', 'قەڵای هەولێر', 'قەڵای مێژوویی هەولێر', 'landmark', 'legendary', '🏰', 'hawler_landmarks'],
      ['cl_minaret', 'minaressa هەولێر', 'بەرجی ناوداری هەولێر', 'landmark', 'epic', '🕌', 'hawler_landmarks'],
      ['cl_sami_park', 'پارکی سامی عەبدولڕەحمان', 'گەشتگا و پارک', 'landmark', 'rare', '🌳', 'hawler_landmarks'],
      ['cl_bazaar', 'بازاڕی هەولێر', 'بازاڕی کۆنی هەولێر', 'landmark', 'rare', '🏪', 'hawler_landmarks'],
      ['cl_golan', 'گولان', 'ناوچەی گولان', 'landmark', 'common', '🏘️', 'hawler_landmarks'],
      ['cl_kurdish_dance', 'گۆرانی کوردی', 'گۆرانی هەڵپەڕکێ', 'culture', 'rare', '💃', 'kurdish_culture'],
      ['cl_traditional_food', 'خواردنی نرخی', 'خواردنی تایبەتی هەولێر', 'culture', 'common', '🍽️', 'kurdish_culture'],
      ['cl_newroz', 'نەورۆز', 'جەژنی نەورۆز', 'culture', 'epic', '🔥', 'kurdish_culture'],
      ['cl_kubba', 'کوبە', 'کوبەی هەولێر', 'food', 'common', '🥘', 'hawler_food'],
      ['cl_dolma', 'دۆلمە', 'دۆلمەی هەولێر', 'food', 'common', '🫔', 'hawler_food'],
      ['cl_biryani', 'بیریانی', 'بیریانی هەولێر', 'food', 'rare', '🍛', 'hawler_food'],
      ['cl_chwarbakh', 'چوارباخ', 'مۆڵەکانی کۆن', 'architecture', 'rare', '🏛️', 'hawler_arch'],
      ['cl_modern', 'بینا مۆدێرن', 'بیناکانی نوێی هەولێر', 'architecture', 'common', '🏗️', 'hawler_arch'],
      ['cl_eagle_sky', 'ئاسمانی هەڵپڕ', 'گەشتی ئاسمانی', 'tourism', 'epic', '🦅', 'hawler_tourism'],
      ['cl_sheikh_shariar', 'شێخ شاڕێر', 'پارکی شێخ شاڕێر', 'tourism', 'common', '🌸', 'hawler_tourism'],
    ];
    for (const [id, title, desc, cat, rarity, icon, set_id] of collectibles) {
      try {
        await run('INSERT INTO collectibles (id, title, description, category, rarity, icon, set_id) VALUES ($1,$2,$3,$4,$5,$6,$7)', [id, title, desc, cat, rarity, icon, set_id]);
      } catch (_) {}
    }
    console.log('✅ Collectibles seeded');
  }

  // Seed seasons if empty
  const sCount = await queryOne('SELECT COUNT(*) as c FROM seasons').catch(() => null);
  if (sCount && parseInt(sCount.c) === 0) {
    console.log('🌱 Seeding seasons...');
    const now = Math.floor(Date.now() / 1000);
    const end = now + (90 * 86400); // 90 days
    try {
      await run('INSERT INTO seasons (id, name, description, start_date, end_date, max_tier, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7)',
        ['season_1', 'وەرزی ١: ڕۆژانی قەڵا', 'یەکەم وەرزی مۆنۆپۆلی هەولێر بە خەڵاتی تایبەت', now, end, 30, 1]);
    } catch (_) {}
    console.log('✅ Seasons seeded');
  }

  // Seed cosmetics if empty
  const cosCount = await queryOne('SELECT COUNT(*) as c FROM cosmetics').catch(() => null);
  if (cosCount && parseInt(cosCount.c) === 0) {
    console.log('🌱 Seeding cosmetics catalog...');
    const cosmetics = [
      ['dice_gold', 'بەردی زێڕین', 'دیزاینی زێڕینی شاهانە', 'dice', 'epic', 1000, 20, '🎲', 'gold_dice', 1, 1],
      ['dice_citadel', 'بەردی قەڵا', 'بەردی نەخشی مێژوویی قەڵا', 'dice', 'rare', 500, 10, '🏰', 'citadel_dice', 1, 2],
      ['dice_neon', 'بەردی نیۆن', 'دیزاینی ڕووناکی شەوانە', 'dice', 'legendary', 2500, 50, '✨', 'neon_dice', 1, 3],
      ['frame_gold', 'چوارچێوەی زێڕ', 'چوارچێوەی زێڕینی ئاست بەرز', 'frame', 'rare', 600, 15, '🖼️', 'gold_frame', 1, 4],
      ['frame_citadel', 'چوارچێوەی قەڵا', 'چوارچێوەی مێژوویی', 'frame', 'epic', 1200, 25, '🏰', 'citadel_frame', 1, 5],
      ['theme_classic', 'کلاسیکی هەولێر', 'دیزاینی ڕەسەن و گەرم', 'theme', 'common', 0, 0, '🎨', 'classic_theme', 1, 6],
      ['theme_night', 'هەولێری شەوانە', 'شاری هەولێر بە ڕووناکی شەو', 'theme', 'epic', 2000, 40, '🌙', 'night_theme', 1, 7],
    ];
    for (const [id, name, desc, cat, rarity, coins, gems, icon, preview, forSale, sortOrder] of cosmetics) {
      try {
        await run('INSERT INTO cosmetics (id, name, description, category, rarity, coin_price, gem_price, icon, preview_asset, is_for_sale, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)',
          [id, name, desc, cat, rarity, coins, gems, icon, preview, forSale, sortOrder]);
      } catch (_) {}
    }
    console.log('✅ Cosmetics seeded');
  }

  // Save SQLite to disk
  const { saveSqlite } = require('./models/database');
  saveSqlite();
  console.log('🎉 Auto-setup complete!');
}

module.exports = { autoSetup };
