const express = require('express');
const { queryOne, query, run } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { generateId, sanitizeText, rateLimit } = require('../utils/validation');

const router = express.Router();

function formatGameMessage(m) {
  return {
    id: m.id,
    senderId: m.sender_id || m.senderId,
    senderName: m.sender_name || m.senderName || 'یاریزان',
    text: m.text || '',
    emoji: m.emoji || null,
    isEmoji: !!(m.is_emoji ?? m.isEmoji),
    timestamp: parseInt(m.timestamp),
    gameRoomId: m.game_room_id || m.gameRoomId,
  };
}

function formatFriendMessage(m) {
  return {
    id: m.id,
    senderId: m.sender_id || m.senderId,
    receiverId: m.receiver_id || m.receiverId,
    text: m.text || '',
    emoji: m.emoji || null,
    isEmoji: !!(m.is_emoji ?? m.isEmoji),
    read: !!m.read,
    timestamp: parseInt(m.timestamp),
  };
}

// ── In-Game Chat ─────────────────────────────────────────────

router.post('/game/:roomId', authMiddleware, async (req, res) => {
  try {
    if (!rateLimit(`chat_${req.userId}`, 60, 60000)) return res.status(429).json({ error: 'زۆر تند ناردنت.' });
    const { text, emoji } = req.body;
    const sanitized = sanitizeText(text || '', 500);
    if (!sanitized && !emoji) return res.status(400).json({ error: 'نامە بەتاڵ ناتوانێت بێت.' });
    const roomId = req.params.roomId.toUpperCase();
    const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [req.userId]);
    const id = generateId();
    const ts = Math.floor(Date.now() / 1000);
    await run('INSERT INTO game_chat_messages (id, game_room_id, sender_id, sender_name, text, emoji, is_emoji, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
      [id, roomId, req.userId, user?.display_name || 'یاریزان', sanitized, emoji || null, emoji ? 1 : 0, ts]);
    
    const message = {
      id,
      senderId: req.userId,
      senderName: user?.display_name || 'یاریزان',
      text: sanitized,
      emoji: emoji || null,
      isEmoji: !!emoji,
      timestamp: ts,
      gameRoomId: roomId,
    };

    // Broadcast over WebSocket
    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(roomId, { type: 'game_chat', message });
    } catch (_) {}

    res.status(201).json({ message });
  } catch (err) {
    console.error('Send game chat error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/game/:roomId', authMiddleware, async (req, res) => {
  try {
    const roomId = req.params.roomId.toUpperCase();
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);
    const messages = await query('SELECT * FROM game_chat_messages WHERE game_room_id = $1 ORDER BY timestamp DESC LIMIT $2', [roomId, limit]);
    res.json({ messages: messages.reverse().map(formatGameMessage) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Quick Reactions in Game ──────────────────────────────────

router.post('/game/:roomId/reaction', authMiddleware, async (req, res) => {
  try {
    const { emoji } = req.body;
    if (!emoji) return res.status(400).json({ error: 'ئێمۆژی پێویستە.' });
    const roomId = req.params.roomId.toUpperCase();
    const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [req.userId]);
    const ts = Math.floor(Date.now() / 1000);

    const payload = {
      type: 'quick_reaction',
      userId: req.userId,
      senderName: user?.display_name || 'یاریزان',
      emoji,
      timestamp: ts,
      roomCode: roomId,
    };

    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(roomId, payload);
    } catch (_) {}

    res.json({ ok: true, reaction: payload });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Friend Chat ──────────────────────────────────────────────

router.post('/friend/:friendId', authMiddleware, async (req, res) => {
  try {
    if (!rateLimit(`fchat_${req.userId}`, 60, 60000)) return res.status(429).json({ error: 'زۆر تند ناردنت.' });
    const { text, emoji } = req.body;
    const sanitized = sanitizeText(text || '', 500);
    if (!sanitized && !emoji) return res.status(400).json({ error: 'نامە بەتاڵ ناتوانێت بێت.' });
    const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [req.userId]);
    const chatId = [req.userId, req.params.friendId].sort().join('_');
    const id = generateId();
    const ts = Math.floor(Date.now() / 1000);
    await run('INSERT INTO friend_chat_messages (id, chat_id, sender_id, receiver_id, text, emoji, is_emoji, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
      [id, chatId, req.userId, req.params.friendId, sanitized, emoji || null, emoji ? 1 : 0, ts]);
    
    const message = {
      id,
      senderId: req.userId,
      senderName: user?.display_name || 'یاریزان',
      receiverId: req.params.friendId,
      text: sanitized,
      emoji: emoji || null,
      isEmoji: !!emoji,
      read: false,
      timestamp: ts,
    };

    // Send real-time notification to friend if online
    try {
      const { sendToUser } = require('../index');
      sendToUser(req.params.friendId, { type: 'friend_chat', message });
    } catch (_) {}

    res.status(201).json({ message });
  } catch (err) {
    console.error('Send friend chat error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/friend/:friendId', authMiddleware, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);
    const chatId = [req.userId, req.params.friendId].sort().join('_');
    const messages = await query('SELECT * FROM friend_chat_messages WHERE chat_id = $1 ORDER BY timestamp DESC LIMIT $2', [chatId, limit]);
    res.json({ messages: messages.reverse().map(formatFriendMessage) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/friend/:friendId/read', authMiddleware, async (req, res) => {
  try {
    const chatId = [req.userId, req.params.friendId].sort().join('_');
    await run('UPDATE friend_chat_messages SET read = 1 WHERE chat_id = $1 AND receiver_id = $2 AND read = 0', [chatId, req.userId]);
    res.json({ marked: true });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/unread', authMiddleware, async (req, res) => {
  try {
    const unread = await query('SELECT sender_id, COUNT(*) as count FROM friend_chat_messages WHERE receiver_id = $1 AND read = 0 GROUP BY sender_id', [req.userId]);
    res.json({ unread: unread.map(u => ({ friendId: u.sender_id, count: parseInt(u.count) })) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
