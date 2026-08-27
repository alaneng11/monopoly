/**
 * Chat Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { run, get, all } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { generateId, sanitizeText, rateLimit } = require('../utils/validation');

const router = express.Router();

// POST /api/chat/game/:roomId
router.post('/game/:roomId', authMiddleware, (req, res) => {
  try {
    if (!rateLimit(`chat_${req.userId}`, 30, 60000)) {
      return res.status(429).json({ error: 'زۆر تند ناردنت — چاوەڕوان بە.' });
    }
    const { text, emoji } = req.body;
    const sanitized = sanitizeText(text || '', 500);
    if (!sanitized && !emoji) return res.status(400).json({ error: 'نامە بەتاڵ ناتوانێت بێت.' });

    const user = get('SELECT display_name FROM users WHERE id = ?', [req.userId]);
    const id = generateId();
    const ts = Math.floor(Date.now() / 1000);

    run(
      'INSERT INTO game_chat_messages (id, game_room_id, sender_id, sender_name, text, emoji, is_emoji, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, req.params.roomId, req.userId, user?.display_name || 'یاریزان', sanitized, emoji || null, emoji ? 1 : 0, ts]
    );

    res.status(201).json({
      message: { id, senderId: req.userId, senderName: user?.display_name || 'یاریزان',
        text: sanitized, emoji: emoji || null, isEmoji: !!emoji, timestamp: ts, gameRoomId: req.params.roomId },
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/chat/game/:roomId
router.get('/game/:roomId', authMiddleware, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);
    const messages = all(
      'SELECT * FROM game_chat_messages WHERE game_room_id = ? ORDER BY timestamp DESC LIMIT ?',
      [req.params.roomId, limit]
    ).reverse();
    res.json({ messages: messages.map(m => ({
      id: m.id, senderId: m.sender_id, senderName: m.sender_name,
      text: m.text, emoji: m.emoji, isEmoji: !!m.is_emoji, timestamp: m.timestamp, gameRoomId: m.game_room_id,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/chat/friend/:friendId
router.post('/friend/:friendId', authMiddleware, (req, res) => {
  try {
    if (!rateLimit(`fchat_${req.userId}`, 30, 60000)) {
      return res.status(429).json({ error: 'زۆر تند ناردنت — چاوەڕوان بە.' });
    }
    const { text, emoji } = req.body;
    const sanitized = sanitizeText(text || '', 500);
    if (!sanitized && !emoji) return res.status(400).json({ error: 'نامە بەتاڵ ناتوانێت بێت.' });

    const chatId = [req.userId, req.params.friendId].sort().join('_');
    const id = generateId();
    const ts = Math.floor(Date.now() / 1000);

    run(
      'INSERT INTO friend_chat_messages (id, chat_id, sender_id, receiver_id, text, emoji, is_emoji, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, chatId, req.userId, req.params.friendId, sanitized, emoji || null, emoji ? 1 : 0, ts]
    );

    res.status(201).json({
      message: { id, senderId: req.userId, receiverId: req.params.friendId,
        text: sanitized, emoji: emoji || null, isEmoji: !!emoji, read: false, timestamp: ts },
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/chat/friend/:friendId
router.get('/friend/:friendId', authMiddleware, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 100, 500);
    const chatId = [req.userId, req.params.friendId].sort().join('_');
    const messages = all(
      'SELECT * FROM friend_chat_messages WHERE chat_id = ? ORDER BY timestamp DESC LIMIT ?',
      [chatId, limit]
    ).reverse();
    res.json({ messages: messages.map(m => ({
      id: m.id, senderId: m.sender_id, receiverId: m.receiver_id,
      text: m.text, emoji: m.emoji, isEmoji: !!m.is_emoji, read: !!m.read, timestamp: m.timestamp,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/chat/friend/:friendId/read
router.post('/friend/:friendId/read', authMiddleware, (req, res) => {
  try {
    const chatId = [req.userId, req.params.friendId].sort().join('_');
    run('UPDATE friend_chat_messages SET read = 1 WHERE chat_id = ? AND receiver_id = ? AND read = 0',
      [chatId, req.userId]);
    res.json({ marked: true });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/chat/unread
router.get('/unread', authMiddleware, (req, res) => {
  try {
    const unread = all(
      'SELECT sender_id, COUNT(*) as count FROM friend_chat_messages WHERE receiver_id = ? AND read = 0 GROUP BY sender_id',
      [req.userId]
    );
    res.json({ unread: unread.map(u => ({ friendId: u.sender_id, count: u.count })) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
