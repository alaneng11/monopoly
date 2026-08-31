/**
 * مۆنۆپۆلی هەولێر — Backend Server v2.0
 * PostgreSQL (Railway production) / SQLite (local dev)
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const http = require('http');
const path = require('path');
const { WebSocketServer } = require('ws');

const { initDb, queryOne, query, run } = require('./models/database');

// Route imports
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const gameRoutes = require('./routes/games');
const leaderboardRoutes = require('./routes/leaderboard');
const chatRoutes = require('./routes/chat');
const friendRoutes = require('./routes/friends');
const rewardRoutes = require('./routes/rewards');
const shopRoutes = require('./routes/shop');
const matchRoutes = require('./routes/matches');

const app = express();
const server = http.createServer(app);

// ── Middleware ───────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Static File Storage (Avatars / Uploads) ──────────────────
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, '../uploads');
app.use('/uploads', express.static(UPLOAD_DIR));

// ── Root Landing Page & Health ──────────────────────────────
app.get('/', async (req, res) => {
  try {
    const userCount = await queryOne('SELECT COUNT(*) as c FROM users');
    const roomCount = await queryOne('SELECT COUNT(*) as c FROM game_rooms');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(`<!DOCTYPE html>
<html lang="ckb" dir="rtl">
<head>
  <meta charset="utf-8">
  <title>مۆنۆپۆلی هەولێر — سێرڤەر</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
    body {
      background: radial-gradient(circle at top, #2A160D 0%, #120B08 100%);
      color: #FBF3E4;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 20px;
    }
    .card {
      background: rgba(28, 18, 12, 0.85);
      border: 1.5px solid #E8B94A;
      box-shadow: 0 20px 50px rgba(0,0,0,0.6), 0 0 30px rgba(232,185,74,0.2);
      border-radius: 24px;
      padding: 36px;
      max-width: 620px;
      width: 100%;
      text-align: center;
    }
    h1 {
      color: #FFE08A;
      font-size: 28px;
      margin-bottom: 8px;
      text-shadow: 0 2px 10px rgba(232,185,74,0.4);
    }
    p.sub {
      color: #E8C99B;
      font-size: 14px;
      margin-bottom: 24px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(47, 191, 113, 0.15);
      color: #2FBF71;
      border: 1px solid #2FBF71;
      padding: 6px 16px;
      border-radius: 20px;
      font-weight: bold;
      font-size: 13px;
      margin-bottom: 24px;
    }
    .status-dot {
      width: 10px;
      height: 10px;
      background: #2FBF71;
      border-radius: 50%;
      box-shadow: 0 0 8px #2FBF71;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;
      text-align: right;
    }
    .stat-box {
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(232,185,74,0.2);
      border-radius: 16px;
      padding: 14px;
    }
    .stat-box .title { font-size: 12px; color: #E8C99B; }
    .stat-box .val { font-size: 20px; font-weight: bold; color: #FFE08A; margin-top: 4px; }
    .btn-play {
      display: block;
      width: 100%;
      background: linear-gradient(180deg, #FFE08A 0%, #E8B94A 100%);
      color: #120B08;
      text-decoration: none;
      font-weight: bold;
      font-size: 16px;
      padding: 14px;
      border-radius: 14px;
      transition: transform 0.2s, box-shadow 0.2s;
      box-shadow: 0 8px 20px rgba(232,185,74,0.3);
      margin-top: 10px;
    }
    .btn-play:hover {
      transform: translateY(-2px);
      box-shadow: 0 12px 25px rgba(232,185,74,0.5);
    }
    .links {
      margin-top: 16px;
      font-size: 12px;
      color: #E8C99B;
    }
    .links a { color: #FFE08A; text-decoration: none; margin: 0 8px; }
    .links a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="card">
    <h1>🏰 مۆنۆپۆلی هەولێر</h1>
    <p class="sub">Hawler Monopoly — Backend Server v2.0 (REST & WebSocket)</p>
    
    <div class="status-badge">
      <span class="status-dot"></span>
      سێرڤەر بە سەرکەوتوویی کار دەکات
    </div>

    <div class="grid">
      <div class="stat-box">
        <div class="title">بنکەدراوە (Database)</div>
        <div class="val">${process.env.DATABASE_URL ? 'PostgreSQL' : 'SQLite Local'}</div>
      </div>
      <div class="stat-box">
        <div class="title">یاریزانە تۆمارکراوەکان</div>
        <div class="val">${userCount?.c || 0}</div>
      </div>
      <div class="stat-box">
        <div class="title">خزمەتگوزاری WebSocket</div>
        <div class="val">ws://localhost:3000/ws</div>
      </div>
      <div class="stat-box">
        <div class="title">ژوورە چالاکەکان</div>
        <div class="val">${roomCount?.c || 0}</div>
      </div>
    </div>

    <a href="http://localhost:5000" class="btn-play">🎮 کردنەوەی یاری (Flutter Web App)</a>

    <div class="links">
      <a href="/health" target="_blank">دۆخی تەندروستی (/health)</a> •
      <a href="http://localhost:5000" target="_blank">پۆرتی یاری (Port 5000)</a>
    </div>
  </div>
</body>
</html>`);
  } catch (err) {
    res.status(500).send(`Server Error: ${err.message}`);
  }
});

// ── Health ──────────────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    const row = await queryOne('SELECT COUNT(*) as c FROM users');
    res.json({
      status: 'ok', service: 'hawler-monopoly-backend', version: '2.0.0',
      timestamp: new Date().toISOString(),
      database: process.env.DATABASE_URL ? 'postgresql' : 'sqlite',
      stats: { users: parseInt(row?.c || 0) },
    });
  } catch (err) {
    res.status(503).json({ status: 'error', error: err.message });
  }
});

// ── Routes ──────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/rooms', gameRoutes);
app.use('/api/games', gameRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/rewards', rewardRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/matches', matchRoutes);

// ── WebSocket ───────────────────────────────────────────────
const wss = new WebSocketServer({ server, path: '/ws' });
const clients = new Map(); // userId → Set<{ws, rooms}>

function broadcastToRoom(roomCode, message, excludeUserId = null) {
  if (!roomCode) return;
  const code = roomCode.toUpperCase();
  const data = JSON.stringify({ ...message, roomCode: code });
  
  // 1. Immediate synchronous broadcast to all clients in room
  for (const [uid, conns] of clients) {
    if (uid === excludeUserId) continue;
    for (const conn of conns) {
      if (conn.rooms.has(code) && conn.ws.readyState === 1) {
        try { conn.ws.send(data); } catch (_) {}
      }
    }
  }

  // 2. DB fallback for reconnected player sockets
  query('SELECT user_id FROM game_room_players WHERE room_code = $1', [code])
    .then(players => {
      for (const p of players) {
        if (p.user_id === excludeUserId) continue;
        const conns = clients.get(p.user_id);
        if (conns) {
          for (const conn of conns) {
            if (!conn.rooms.has(code) && conn.ws.readyState === 1) {
              conn.rooms.add(code);
              try { conn.ws.send(data); } catch (_) {}
            }
          }
        }
      }
    })
    .catch(() => {});
}

function sendToUser(userId, message) {
  const data = JSON.stringify(message);
  if (!clients.has(userId)) return false;
  const conns = clients.get(userId);
  let sent = false;
  for (const conn of conns) {
    if (conn.ws.readyState === 1) {
      conn.ws.send(data);
      sent = true;
    }
  }
  return sent;
}

wss.on('connection', (ws, req) => {
  let userId = null;
  let clientRooms = new Set();

  ws.on('message', async (data) => {
    try {
      const msg = JSON.parse(data.toString());
      switch (msg.type) {
        case 'auth': {
          try {
            const { verifyToken } = require('./middleware/auth');
            const decoded = verifyToken(msg.token);
            userId = decoded.userId;
            if (!clients.has(userId)) clients.set(userId, new Set());
            clients.get(userId).add({ ws, rooms: clientRooms });
            ws.send(JSON.stringify({ type: 'auth_ok', userId }));
          } catch (e) {
            ws.send(JSON.stringify({ type: 'auth_error', error: 'توکن نادروستە.' }));
          }
          break;
        }
        case 'join_room': {
          if (!userId) break;
          if (msg.roomCode) {
            const code = msg.roomCode.toUpperCase();
            clientRooms.add(code);
            broadcastToRoom(code, { type: 'player_joined', userId, roomCode: code }, userId);
            ws.send(JSON.stringify({ type: 'room_joined', roomCode: code }));
          }
          break;
        }
        case 'leave_room': {
          if (!userId || !msg.roomCode) break;
          const code = msg.roomCode.toUpperCase();
          clientRooms.delete(code);
          broadcastToRoom(code, { type: 'player_left', userId, roomCode: code }, userId);
          break;
        }
        case 'game_chat': {
          if (!userId || !msg.roomCode || (!msg.text && !msg.emoji)) break;
          const code = msg.roomCode.toUpperCase();
          const engine = require('./services/game_engine');
          const chatMsg = await engine.sendChatMessage(code, userId, msg.text, msg.emoji);
          broadcastToRoom(code, { type: 'game_chat', message: chatMsg });
          break;
        }
        case 'quick_reaction': {
          if (!userId || !msg.roomCode || !msg.emoji) break;
          const code = msg.roomCode.toUpperCase();
          const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [userId]);
          broadcastToRoom(code, {
            type: 'quick_reaction',
            userId,
            senderName: user?.display_name || 'یاریزان',
            emoji: msg.emoji,
            timestamp: Math.floor(Date.now() / 1000),
            roomCode: code,
          });
          break;
        }
        case 'friend_chat': {
          if (!userId || !msg.friendId || (!msg.text && !msg.emoji)) break;
          const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [userId]);
          const { generateId, sanitizeText } = require('./utils/validation');
          const sanitized = sanitizeText(msg.text || '', 500);
          const chatId = [userId, msg.friendId].sort().join('_');
          const id = generateId();
          const ts = Math.floor(Date.now() / 1000);
          await run('INSERT INTO friend_chat_messages (id, chat_id, sender_id, receiver_id, text, emoji, is_emoji, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
            [id, chatId, userId, msg.friendId, sanitized, msg.emoji || null, msg.emoji ? 1 : 0, ts]);
          const payload = {
            type: 'friend_chat',
            message: {
              id,
              senderId: userId,
              senderName: user?.display_name || 'یاریزان',
              receiverId: msg.friendId,
              text: sanitized,
              emoji: msg.emoji || null,
              isEmoji: !!msg.emoji,
              read: false,
              timestamp: ts,
            }
          };
          sendToUser(msg.friendId, payload);
          ws.send(JSON.stringify(payload));
          break;
        }
        case 'auction_bid': {
          if (!userId || !msg.roomCode || !msg.amount) break;
          const code = msg.roomCode.toUpperCase();
          const engine = require('./services/game_engine');
          try {
            const auction = await engine.placeAuctionBid(code, userId, parseInt(msg.amount));
            const state = await engine.getState(code);
            broadcastToRoom(code, { type: 'auction_updated', auction, state });
          } catch (err) {
            ws.send(JSON.stringify({ type: 'error', message: err.message }));
          }
          break;
        }
        case 'auction_pass': {
          if (!userId || !msg.roomCode) break;
          const code = msg.roomCode.toUpperCase();
          const engine = require('./services/game_engine');
          try {
            const auction = await engine.passAuctionBid(code, userId);
            const state = await engine.getState(code);
            broadcastToRoom(code, { type: 'auction_updated', auction, state });
          } catch (err) {
            ws.send(JSON.stringify({ type: 'error', message: err.message }));
          }
          break;
        }
        case 'trade_propose': {
          if (!userId || !msg.roomCode || !msg.toPlayerId) break;
          const code = msg.roomCode.toUpperCase();
          const engine = require('./services/game_engine');
          try {
            const trade = await engine.proposeTrade(code, userId, msg.toPlayerId, msg.fromMoney, msg.toMoney, msg.fromTileIndices, msg.toTileIndices);
            const state = await engine.getState(code);
            broadcastToRoom(code, { type: 'trade_updated', trade, state });
          } catch (err) {
            ws.send(JSON.stringify({ type: 'error', message: err.message }));
          }
          break;
        }
        case 'trade_respond': {
          if (!userId || !msg.roomCode) break;
          const code = msg.roomCode.toUpperCase();
          const engine = require('./services/game_engine');
          try {
            const result = await engine.respondTrade(code, userId, !!msg.accept);
            const state = await engine.getState(code);
            broadcastToRoom(code, { type: 'trade_resolved', result, state });
          } catch (err) {
            ws.send(JSON.stringify({ type: 'error', message: err.message }));
          }
          break;
        }
        case 'spectate_room': {
          if (!userId || !msg.roomCode) break;
          const code = msg.roomCode.toUpperCase();
          clientRooms.add(code);
          const engine = require('./services/game_engine');
          const state = await engine.getState(code);
          ws.send(JSON.stringify({ type: 'spectate_joined', roomCode: code, state }));
          break;
        }
        case 'game_state_update': {
          if (!userId || !msg.roomCode) break;
          const code = msg.roomCode.toUpperCase();
          broadcastToRoom(code, { type: 'game_state_update', state: msg.state, version: msg.version }, userId);
          break;
        }
      }
    } catch (e) { /* ignore */ }
  });

  ws.on('close', () => {
    if (userId && clients.has(userId)) {
      const conns = clients.get(userId);
      for (const conn of conns) {
        if (conn.ws === ws) { conns.delete(conn); break; }
      }
      if (conns.size === 0) clients.delete(userId);
    }
    for (const room of clientRooms) {
      broadcastToRoom(room, { type: 'player_disconnected', userId }, userId);
    }
  });

  ws.on('error', () => {});
});

// ── Start ───────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;

(async () => {
  try {
    await initDb();
    console.log('✅ Database initialized');
    
    // Auto-run migrations and seed on startup
    try {
      const { autoSetup } = require('./auto_setup');
      await autoSetup();
    } catch (e) {
      console.log('⚠️ Auto-setup skipped:', e.message);
    }

    // Ensure turn_started_at column exists (safe ALTER TABLE)
    try {
      await run('ALTER TABLE game_states ADD COLUMN IF NOT EXISTS turn_started_at BIGINT');
    } catch (_) {
      try {
        // SQLite fallback — column may not exist yet, silently skip if it does
        const cols = await query("PRAGMA table_info(game_states)");
        if (!cols.some(c => c.name === 'turn_started_at')) {
          await run('ALTER TABLE game_states ADD COLUMN turn_started_at BIGINT');
        }
      } catch (__) {}
    }
  } catch (err) {
    console.error('❌ Database failed:', err.message);
    process.exit(1);
  }

  server.listen(PORT, () => {
    console.log(`🏰 مۆنۆپۆلی هەولێر backend v2.0 on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   WebSocket: ws://localhost:${PORT}/ws`);
    console.log(`   Uploads: ${UPLOAD_DIR}`);

    // Start server-side turn timer (auto-advance stalled games after 30s)
    const { startTurnTimerScheduler } = require('./services/game_engine');
    startTurnTimerScheduler(broadcastToRoom);

    // Periodic cleanup scheduler: clean abandoned rooms & expired sessions older than 24h
    setInterval(async () => {
      try {
        const dayAgo = Math.floor(Date.now() / 1000) - 86400;
        await run("DELETE FROM game_rooms WHERE status = 'closed' AND updated_at < $1", [dayAgo]);
        await run("DELETE FROM user_sessions WHERE last_active < $1", [dayAgo]);
      } catch (_) {}
    }, 3600000);
  });
})();

module.exports = { app, server, broadcastToRoom, sendToUser };
