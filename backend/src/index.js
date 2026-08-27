/**
 * مۆنۆپۆلی هەولێر — Backend Server v2.0
 * PostgreSQL (Railway production) / SQLite (local dev)
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const http = require('http');
const { WebSocketServer } = require('ws');

const { initDb, queryOne, query, run } = require('./models/database');

// Route imports
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const gameRoutes = require('./routes/games');
const leaderboardRoutes = require('./routes/leaderboard');
const chatRoutes = require('./routes/chat');
const friendRoutes = require('./routes/friends');

const app = express();
const server = http.createServer(app);

// ── Middleware ───────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] }));
app.use(express.json({ limit: '1mb' }));

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

// ── WebSocket ───────────────────────────────────────────────
const wss = new WebSocketServer({ server, path: '/ws' });
const clients = new Map(); // userId → Set<{ws, rooms}>

function broadcastToRoom(roomCode, message, excludeUserId = null) {
  const data = JSON.stringify(message);
  // Get all players in this room
  query('SELECT user_id FROM game_room_players WHERE room_code = $1', [roomCode])
    .then(players => {
      const playerIds = new Set(players.map(p => p.user_id));
      for (const [uid, conns] of clients) {
        if (uid === excludeUserId || !playerIds.has(uid)) continue;
        for (const conn of conns) {
          if (conn.rooms.has(roomCode) && conn.ws.readyState === 1) {
            conn.ws.send(data);
          }
        }
      }
    })
    .catch(() => {});
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
            clientRooms.add(msg.roomCode);
            broadcastToRoom(msg.roomCode, { type: 'player_joined', userId }, userId);
            ws.send(JSON.stringify({ type: 'room_joined', roomCode: msg.roomCode }));
          }
          break;
        }
        case 'leave_room': {
          if (!userId || !msg.roomCode) break;
          clientRooms.delete(msg.roomCode);
          broadcastToRoom(msg.roomCode, { type: 'player_left', userId }, userId);
          break;
        }
        case 'game_chat': {
          if (!userId || !msg.roomCode || !msg.text) break;
          const engine = require('./services/game_engine');
          const chatMsg = await engine.sendChatMessage(msg.roomCode, userId, msg.text, msg.emoji);
          broadcastToRoom(msg.roomCode, { type: 'game_chat', message: chatMsg });
          break;
        }
        case 'game_state_update': {
          if (!userId || !msg.roomCode) break;
          broadcastToRoom(msg.roomCode, { type: 'game_state_update', state: msg.state, version: msg.version }, userId);
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
  } catch (err) {
    console.error('❌ Database failed:', err.message);
    process.exit(1);
  }

  server.listen(PORT, () => {
    console.log(`🏰 مۆنۆپۆلی هەولێر backend v2.0 on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   WebSocket: ws://localhost:${PORT}/ws`);
  });
})();

module.exports = { app, server, broadcastToRoom };
