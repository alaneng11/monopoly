/**
 * Database Abstraction — مۆنۆپۆلی هەولێر
 *
 * Uses PostgreSQL when DATABASE_URL is set (Railway production),
 * falls back to SQLite (sql.js) for local development.
 */

const fs = require('fs');
const path = require('path');

const USE_PG = !!process.env.DATABASE_URL;
let pgPool = null;
let sqlJsDb = null;

// ── Connection ──────────────────────────────────────────────

async function initDb() {
  if (USE_PG) {
    const { Pool } = require('pg');
    pgPool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
      max: 20,
      idleTimeoutMillis: 30000,
    });
    // Test connection
    const r = await pgPool.query('SELECT NOW()');
    console.log('✅ PostgreSQL connected:', r.rows[0].now);
  } else {
    const initSqlJs = require('sql.js');
    const SQL = await initSqlJs();
    const dbPath = process.env.DB_PATH || path.join(__dirname, '..', 'data.db');
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    if (fs.existsSync(dbPath)) {
      sqlJsDb = new SQL.Database(fs.readFileSync(dbPath));
    } else {
      sqlJsDb = new SQL.Database();
    }
    sqlJsDb.run('PRAGMA journal_mode = WAL');
    sqlJsDb.run('PRAGMA foreign_keys = ON');
    console.log('✅ SQLite connected:', dbPath);
  }
}

// ── Query helpers ───────────────────────────────────────────

async function query(sql, params = []) {
  if (USE_PG) {
    const r = await pgPool.query(sql, params);
    return r.rows;
  }
  return _sqliteQuery(sql, params);
}

async function queryOne(sql, params = []) {
  const rows = await query(sql, params);
  return rows[0] || undefined;
}

async function run(sql, params = []) {
  if (USE_PG) {
    const r = await pgPool.query(sql, params);
    return { changes: r.rowCount, lastInsertRowId: r.rows[0]?.id };
  }
  _sqliteRun(sql, params);
  const ch = sqlJsDb.getRowsModified();
  return { changes: ch };
}

async function transaction(fn) {
  if (USE_PG) {
    const client = await pgPool.connect();
    try {
      await client.query('BEGIN');
      const result = await fn({
        query: (s, p) => client.query(s, p).then(r => r.rows),
        queryOne: async (s, p) => { const r = await client.query(s, p); return r.rows[0]; },
        run: async (s, p) => { const r = await client.query(s, p); return { changes: r.rowCount }; },
      });
      await client.query('COMMIT');
      return result;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
  // SQLite transaction
  _sqliteRun('BEGIN');
  try {
    const result = await fn({
      query: (s, p) => Promise.resolve(_sqliteQuery(s, p)),
      queryOne: async (s, p) => _sqliteQuery(s, p)[0],
      run: async (s, p) => { _sqliteRun(s, p); return { changes: sqlJsDb.getRowsModified() }; },
    });
    _sqliteRun('COMMIT');
    return result;
  } catch (e) {
    _sqliteRun('ROLLBACK');
    throw e;
  }
}

// ── SQLite internals ────────────────────────────────────────

function _sqliteQuery(sql, params = []) {
  const stmt = sqlJsDb.prepare(sql);
  stmt.bind(params);
  const rows = [];
  while (stmt.step()) {
    const cols = stmt.getColumnNames();
    const vals = stmt.get();
    const row = {};
    cols.forEach((c, i) => row[c] = vals[i]);
    rows.push(row);
  }
  stmt.free();
  return rows;
}

function _sqliteRun(sql, params = []) {
  sqlJsDb.run(sql, params);
}

// ── Periodic save (SQLite only) ─────────────────────────────

if (!USE_PG) {
  setInterval(() => {
    if (sqlJsDb) {
      try {
        const data = sqlJsDb.export();
        const dbPath = process.env.DB_PATH || path.join(__dirname, '..', 'data.db');
        fs.writeFileSync(dbPath, Buffer.from(data));
      } catch (_) {}
    }
  }, 30000);
}

function saveSqlite() {
  if (!USE_PG && sqlJsDb) {
    const data = sqlJsDb.export();
    const dbPath = process.env.DB_PATH || path.join(__dirname, '..', 'data.db');
    fs.writeFileSync(dbPath, Buffer.from(data));
  }
}

module.exports = { initDb, query, queryOne, run, transaction, saveSqlite, USE_PG };
