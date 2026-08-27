/**
 * SQLite Database Setup — مۆنۆپۆلی هەولێر
 * 
 * Uses sql.js (pure JavaScript SQLite via WASM) for cross-platform compatibility.
 * Supports WAL mode for concurrent read performance.
 */

const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', '..', 'data.db');

let db = null;
let dbReady = null;

/**
 * Get or initialize the database.
 * Returns a promise that resolves to the database instance.
 */
async function getDbAsync() {
  if (db) return db;
  if (dbReady) return dbReady;
  
  dbReady = (async () => {
    const SQL = await initSqlJs();
    
    // Ensure parent directory exists
    const dbDir = path.dirname(DB_PATH);
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }
    
    // Load existing database or create new one
    if (fs.existsSync(DB_PATH)) {
      const buffer = fs.readFileSync(DB_PATH);
      db = new SQL.Database(buffer);
    } else {
      db = new SQL.Database();
    }
    
    // Enable WAL mode (sql.js supports this via pragma)
    db.run('PRAGMA journal_mode = WAL');
    db.run('PRAGMA foreign_keys = ON');
    
    initializeTables();
    saveDb();
    
    console.log('✅ Database initialized at', DB_PATH);
    return db;
  })();
  
  return dbReady;
}

/**
 * Synchronous getter — only call after getDbAsync() has resolved.
 */
function getDb() {
  if (!db) {
    throw new Error('Database not initialized. Call getDbAsync() first.');
  }
  return db;
}

/**
 * Persist database to disk.
 */
function saveDb() {
  if (!db) return;
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(DB_PATH, buffer);
}

/**
 * Auto-save periodically (every 30 seconds).
 */
setInterval(() => {
  if (db) {
    try { saveDb(); } catch (_) {}
  }
}, 30000);

/**
 * Wrapper for prepared statements — sql.js uses a different API.
 */
function run(sql, params = []) {
  db.run(sql, params);
  saveDb();
}

function get(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  if (stmt.step()) {
    const cols = stmt.getColumnNames();
    const vals = stmt.get();
    stmt.free();
    const row = {};
    cols.forEach((col, i) => row[col] = vals[i]);
    return row;
  }
  stmt.free();
  return undefined;
}

function all(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const rows = [];
  while (stmt.step()) {
    const cols = stmt.getColumnNames();
    const vals = stmt.get();
    const row = {};
    cols.forEach((col, i) => row[col] = vals[i]);
    rows.push(row);
  }
  stmt.free();
  return rows;
}

function exec(sql) {
  db.exec(sql);
  saveDb();
}

function initializeTables() {
  exec(`
    -- ================================================
    -- Users & Authentication
    -- ================================================
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
      last_login_at INTEGER,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
    CREATE INDEX IF NOT EXISTS idx_users_xp ON users(xp DESC);

    -- ================================================
    -- Authentication Tokens
    -- ================================================
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      token_hash TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      revoked INTEGER NOT NULL DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

    -- ================================================
    -- Game Rooms
    -- ================================================
    CREATE TABLE IF NOT EXISTS game_rooms (
      code TEXT PRIMARY KEY,
      host_id TEXT NOT NULL,
      room_name TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'lobby',
      max_players INTEGER NOT NULL DEFAULT 6,
      is_public INTEGER NOT NULL DEFAULT 0,
      start_cash INTEGER NOT NULL DEFAULT 1500,
      version INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS game_room_players (
      room_code TEXT NOT NULL,
      user_id TEXT NOT NULL,
      character_id TEXT NOT NULL DEFAULT 'business',
      ready INTEGER NOT NULL DEFAULT 0,
      connected INTEGER NOT NULL DEFAULT 1,
      joined_at INTEGER NOT NULL DEFAULT (unixepoch()),
      PRIMARY KEY (room_code, user_id)
    );

    -- ================================================
    -- Game State (Server-Authoritative)
    -- ================================================
    CREATE TABLE IF NOT EXISTS game_states (
      room_code TEXT PRIMARY KEY,
      round INTEGER NOT NULL DEFAULT 1,
      current_player_index INTEGER NOT NULL DEFAULT 0,
      phase TEXT NOT NULL DEFAULT 'awaitingRoll',
      dice TEXT NOT NULL DEFAULT '[1,1]',
      players TEXT NOT NULL DEFAULT '[]',
      tiles TEXT NOT NULL DEFAULT '{}',
      free_coins INTEGER NOT NULL DEFAULT 0,
      winner_id TEXT DEFAULT '',
      seed INTEGER NOT NULL DEFAULT 0,
      dice_multiplier INTEGER NOT NULL DEFAULT 1,
      dice_energy INTEGER NOT NULL DEFAULT 10,
      turn_token INTEGER NOT NULL DEFAULT 0,
      version INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    -- ================================================
    -- Match History
    -- ================================================
    CREATE TABLE IF NOT EXISTS match_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_code TEXT NOT NULL,
      winner_id TEXT,
      winner_name TEXT NOT NULL DEFAULT '',
      player_ids TEXT NOT NULL DEFAULT '[]',
      player_names TEXT NOT NULL DEFAULT '[]',
      round INTEGER NOT NULL DEFAULT 0,
      duration_seconds INTEGER NOT NULL DEFAULT 0,
      final_net_worth INTEGER NOT NULL DEFAULT 0,
      played_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_match_history_winner ON match_history(winner_id);
    CREATE INDEX IF NOT EXISTS idx_match_history_played ON match_history(played_at DESC);

    -- ================================================
    -- Leaderboard
    -- ================================================
    CREATE TABLE IF NOT EXISTS leaderboard (
      user_id TEXT PRIMARY KEY,
      weekly_xp INTEGER NOT NULL DEFAULT 0,
      monthly_xp INTEGER NOT NULL DEFAULT 0,
      total_xp INTEGER NOT NULL DEFAULT 0,
      weekly_wins INTEGER NOT NULL DEFAULT 0,
      monthly_wins INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_leaderboard_weekly ON leaderboard(weekly_xp DESC);
    CREATE INDEX IF NOT EXISTS idx_leaderboard_monthly ON leaderboard(monthly_xp DESC);
    CREATE INDEX IF NOT EXISTS idx_leaderboard_total ON leaderboard(total_xp DESC);

    -- ================================================
    -- Achievements
    -- ================================================
    CREATE TABLE IF NOT EXISTS user_achievements (
      user_id TEXT NOT NULL,
      achievement_id TEXT NOT NULL,
      unlocked_at INTEGER NOT NULL DEFAULT (unixepoch()),
      PRIMARY KEY (user_id, achievement_id)
    );

    -- ================================================
    -- Friends
    -- ================================================
    CREATE TABLE IF NOT EXISTS friendships (
      user_id TEXT NOT NULL,
      friend_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      PRIMARY KEY (user_id, friend_id)
    );

    CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);
    CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);

    -- ================================================
    -- Chat Messages
    -- ================================================
    CREATE TABLE IF NOT EXISTS game_chat_messages (
      id TEXT PRIMARY KEY,
      game_room_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      sender_name TEXT NOT NULL DEFAULT '',
      text TEXT NOT NULL DEFAULT '',
      emoji TEXT,
      is_emoji INTEGER NOT NULL DEFAULT 0,
      timestamp INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_game_chat_room ON game_chat_messages(game_room_id, timestamp);

    CREATE TABLE IF NOT EXISTS friend_chat_messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      receiver_id TEXT NOT NULL,
      text TEXT NOT NULL DEFAULT '',
      emoji TEXT,
      is_emoji INTEGER NOT NULL DEFAULT 0,
      read INTEGER NOT NULL DEFAULT 0,
      timestamp INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_friend_chat_id ON friend_chat_messages(chat_id, timestamp);
    CREATE INDEX IF NOT EXISTS idx_friend_chat_receiver ON friend_chat_messages(receiver_id, read);

    -- ================================================
    -- Challenges
    -- ================================================
    CREATE TABLE IF NOT EXISTS user_challenges (
      user_id TEXT NOT NULL,
      challenge_id TEXT NOT NULL,
      progress INTEGER NOT NULL DEFAULT 0,
      target INTEGER NOT NULL DEFAULT 1,
      completed INTEGER NOT NULL DEFAULT 0,
      claimed INTEGER NOT NULL DEFAULT 0,
      period TEXT NOT NULL DEFAULT 'daily',
      period_start INTEGER NOT NULL,
      PRIMARY KEY (user_id, challenge_id, period_start)
    );

    -- ================================================
    -- Transactions Ledger (economy audit)
    -- ================================================
    CREATE TABLE IF NOT EXISTS transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      room_code TEXT,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      amount INTEGER NOT NULL,
      reason TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    );

    CREATE INDEX IF NOT EXISTS idx_transactions_room ON transactions(room_code, created_at);
    CREATE INDEX IF NOT EXISTS idx_transactions_from ON transactions(from_id, created_at);
  `);
}

module.exports = { getDbAsync, getDb, run, get, all, exec, saveDb };
