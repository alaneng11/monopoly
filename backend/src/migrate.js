/**
 * Database Migration — مۆنۆپۆلی هەولێر
 *
 * Creates all production tables.
 * Run with: node src/migrate.js
 *
 * Idempotent — safe to run multiple times.
 */

const { initDb, query, run, USE_PG } = require('./models/database');

const UP = `
-- ════════════════════════════════════════════════════════════
-- 1. USERS & AUTH
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 2. PLAYER PROFILES
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS player_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  title TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  selected_avatar TEXT DEFAULT 'business',
  selected_title TEXT DEFAULT '',
  cosmetics JSONB DEFAULT '{}',
  stats JSONB DEFAULT '{}'
);

-- ════════════════════════════════════════════════════════════
-- 3. GAME ROOMS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 4. GAME ROOM PLAYERS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 5. GAME STATE (Server-Authoritative)
-- ════════════════════════════════════════════════════════════
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
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- ════════════════════════════════════════════════════════════
-- 6. PROPERTIES (Board tiles with ownership)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS properties (
  id SERIAL PRIMARY KEY,
  room_code TEXT NOT NULL REFERENCES game_rooms(code) ON DELETE CASCADE,
  tile_index INTEGER NOT NULL,
  owner_id TEXT REFERENCES users(id),
  level INTEGER NOT NULL DEFAULT 0,
  mortgaged INTEGER NOT NULL DEFAULT 0,
  UNIQUE(room_code, tile_index)
);

-- ════════════════════════════════════════════════════════════
-- 7. TRANSACTIONS (Financial Audit)
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 8. TRADES
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 9. AUCTIONS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 10. GAME CHAT
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 11. FRIEND CHAT
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 12. FRIENDSHIPS
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS friendships (
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  accepted_at BIGINT,
  PRIMARY KEY (user_id, friend_id)
);

-- ════════════════════════════════════════════════════════════
-- 13. ACHIEVEMENTS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 14. MISSIONS / CHALLENGES
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 15. DAILY REWARDS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 16. COLLECTIBLES
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 17. MATCH HISTORY
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 18. LEADERBOARD
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS leaderboard (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  weekly_xp INTEGER NOT NULL DEFAULT 0,
  monthly_xp INTEGER NOT NULL DEFAULT 0,
  total_xp INTEGER NOT NULL DEFAULT 0,
  weekly_wins INTEGER NOT NULL DEFAULT 0,
  monthly_wins INTEGER NOT NULL DEFAULT 0,
  updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);

-- ════════════════════════════════════════════════════════════
-- 19. PLAYER STATISTICS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 20. NOTIFICATIONS
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 21. GAME EVENTS (Dynamic game modifiers)
-- ════════════════════════════════════════════════════════════
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

-- ════════════════════════════════════════════════════════════
-- 22. USER SESSIONS (Reconnect support)
-- ════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS user_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_code TEXT,
  ws_id TEXT,
  last_active BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_session_user ON user_sessions(user_id);
`;

// SQLite-specific: adapt PostgreSQL syntax
const UP_SQLITE = UP
  .replace(/DEFAULT \(extract\(epoch from now\(\)\)::bigint\)/g, 'DEFAULT (unixepoch())')
  .replace(/JSONB/g, 'TEXT')
  .replace(/REAL/g, 'REAL');

async function migrate() {
  await initDb();
  
  const sql = USE_PG ? UP : UP_SQLITE;
  // Split by semicolons and execute each statement
  const statements = sql.split(';').map(s => s.trim()).filter(s => s.length > 0);
  
  let count = 0;
  for (const stmt of statements) {
    try {
      await run(stmt);
      count++;
    } catch (e) {
      // Skip already-existing constraints
      if (!e.message?.includes('already exists')) {
        console.error(`Migration error: ${e.message}\n  SQL: ${stmt.substring(0, 80)}...`);
      }
    }
  }
  
  console.log(`✅ Migration complete: ${count} statements executed`);
  console.log(`   Database: ${USE_PG ? 'PostgreSQL' : 'SQLite'}`);
  // Explicitly save SQLite to disk before exit
  const { saveSqlite } = require('./models/database');
  saveSqlite();
  process.exit(0);
}

migrate().catch(e => { console.error('❌ Migration failed:', e.message); process.exit(1); });
