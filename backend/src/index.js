/**
 * مۆنۆپۆلی هەولێر — Backend Server
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const http = require('http');
const { WebSocketServer } = require('ws');

const { getDbAsync, getDb, run, get, all } = require('./models/database');
const { authMiddleware, optionalAuth } = require('./middleware/auth');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const gameRoutes = require('./routes/games');
const leaderboardRoutes = require('./routes/leaderboard');
const chatRoutes = require('./routes/chat');
const friendRoutes = require('./routes/friends');

const app = express();
const server = http.createServer(app);

// ============================================
// Middleware
// ============================================
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] }));
app.use(express.json({ limit: '1mb' }));

// ============================================
// Health Check
// ============================================
app.get('/health', async (req, res) => {
  try {
    const db = getDb();
    const userCount = get('SELECT COUNT(*) as c FROM users');
    res.json({
      status: 'ok',
      service: 'hawler-monopoly-backend',
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      stats: { users: userCount?.c || 0 },
    });
  } catch (err) {
    res.status(503).json({ status: 'error', error: err.message });
  }
});

// ============================================
// API Routes
// ============================================
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/rooms', gameRoutes);
app.use('/api/games', gameRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/friends', friendRoutes);

// ============================================
// WebSocket — Real-time Multiplayer & Chat
// ============================================
const wss = new WebSocketServer({ server, path: '/ws' });
const clients = new Map();

wss.on('connection', (ws, req) => {
  let userId = null;
  let clientRooms = new Set();

  ws.on('message', (data) => {
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
          if (!userId) return ws.send(JSON.stringify({ type: 'error', error: 'سەرەتا بچۆرە ژوورەوە.' }));
          if (msg.roomCode) {
            clientRooms.add(msg.roomCode);
            broadcastToRoom(msg.roomCode, { type: 'player_joined', userId }, userId);
            ws.send(JSON.stringify({ type: 'room_joined', roomCode: msg.roomCode }));
          }
          break;
        }
        case 'leave_room': {
          if (!userId || !msg.roomCode) return;
          clientRooms.delete(msg.roomCode);
          broadcastToRoom(msg.roomCode, { type: 'player_left', userId }, userId);
          break;
        }
        case 'game_chat': {
          if (!userId || !msg.roomCode || !msg.text) return;
          const { generateId, sanitizeText } = require('./utils/validation');
          const user = get('SELECT display_name FROM users WHERE id = ?', [userId]);
          const chatMsg = {
            id: generateId(), senderId: userId,
            senderName: user?.display_name || 'یاریزان',
            text: sanitizeText(msg.text, 500),
            emoji: msg.emoji || null, isEmoji: !!msg.emoji,
            timestamp: Math.floor(Date.now() / 1000),
            gameRoomId: msg.roomCode,
          };
          run(
            'INSERT INTO game_chat_messages (id, game_room_id, sender_id, sender_name, text, emoji, is_emoji, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [chatMsg.id, msg.roomCode, chatMsg.senderId, chatMsg.senderName, chatMsg.text, chatMsg.emoji, chatMsg.isEmoji ? 1 : 0, chatMsg.timestamp]
          );
          broadcastToRoom(msg.roomCode, { type: 'game_chat', message: chatMsg });
          break;
        }
        case 'game_chat_emoji': {
          if (!userId || !msg.roomCode || !msg.emoji) return;
          broadcastToRoom(msg.roomCode, {
            type: 'game_chat_emoji', emoji: msg.emoji, senderId: userId,
            timestamp: Math.floor(Date.now() / 1000),
          });
          break;
        }
        case 'game_state_update': {
          if (!userId || !msg.roomCode) return;
          broadcastToRoom(msg.roomCode, {
            type: 'game_state_update', state: msg.state, version: msg.version,
          }, userId);
          break;
        }
      }
    } catch (e) { /* ignore malformed messages */ }
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

function broadcastToRoom(roomCode, message, excludeUserId = null) {
  try {
    const players = all('SELECT user_id FROM game_room_players WHERE room_code = ?', [roomCode]);
    const playerIds = new Set(players.map(p => p.user_id));
    const data = JSON.stringify(message);
    for (const [uid, conns] of clients) {
      if (uid === excludeUserId || !playerIds.has(uid)) continue;
      for (const conn of conns) {
        if (conn.rooms.has(roomCode) && conn.ws.readyState === 1) {
          conn.ws.send(data);
        }
      }
    }
  } catch (_) {}
}

// ============================================
// Start Server
// ============================================
const PORT = process.env.PORT || 3000;

(async () => {
  try {
    await getDbAsync();
    console.log('✅ Database initialized');
  } catch (err) {
    console.error('❌ Database initialization failed:', err.message);
    process.exit(1);
  }

  server.listen(PORT, () => {
    console.log(`🏰 مۆنۆپۆلی هەولێر backend running on port ${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   WebSocket: ws://localhost:${PORT}/ws`);
  });
})();

module.exports = { app, server };
