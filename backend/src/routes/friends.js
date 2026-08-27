/**
 * Friends Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { run, get, all } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// GET /api/friends
router.get('/', authMiddleware, (req, res) => {
  try {
    const friends = all(`
      SELECT u.id, u.display_name, u.level, u.avatar_url, f.status, f.created_at
      FROM friendships f
      JOIN users u ON (u.id = f.friend_id AND f.user_id = ?) OR (u.id = f.user_id AND f.friend_id = ?)
      WHERE (f.user_id = ? OR f.friend_id = ?) AND f.status = 'accepted'
    `, [req.userId, req.userId, req.userId, req.userId]);

    res.json({
      friends: friends.map(f => ({
        id: f.id, displayName: f.display_name, level: f.level, avatarUrl: f.avatar_url,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/friends/add/:id
router.post('/add/:id', authMiddleware, (req, res) => {
  try {
    if (req.params.id === req.userId) {
      return res.status(400).json({ error: 'ناتوانیت خۆت هاوڕێی خۆت بکەیت.' });
    }
    const target = get('SELECT id FROM users WHERE id = ?', [req.params.id]);
    if (!target) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    const existing = get(
      'SELECT status FROM friendships WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
      [req.userId, req.params.id, req.params.id, req.userId]
    );
    if (existing) {
      if (existing.status === 'accepted') return res.json({ message: 'پێشتر هاوڕێن.' });
      if (existing.status === 'pending') return res.json({ message: 'داواکاری پێشتر نێردراوە.' });
    }

    run('INSERT OR REPLACE INTO friendships (user_id, friend_id, status) VALUES (?, ?, ?)',
      [req.userId, req.params.id, 'pending']);
    res.status(201).json({ message: 'داواکاری نێردرا.' });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/friends/accept/:id
router.post('/accept/:id', authMiddleware, (req, res) => {
  try {
    const request = get(
      'SELECT * FROM friendships WHERE user_id = ? AND friend_id = ? AND status = ?',
      [req.params.id, req.userId, 'pending']
    );
    if (!request) return res.status(404).json({ error: 'داواکاری نەدۆزرایەوە.' });

    run('UPDATE friendships SET status = ? WHERE user_id = ? AND friend_id = ?',
      ['accepted', req.params.id, req.userId]);
    run('INSERT OR REPLACE INTO friendships (user_id, friend_id, status) VALUES (?, ?, ?)',
      [req.userId, req.params.id, 'accepted']);
    res.json({ message: 'هاوڕێ بوو! 🎉' });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/friends/remove/:id
router.post('/remove/:id', authMiddleware, (req, res) => {
  try {
    run('DELETE FROM friendships WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
      [req.userId, req.params.id, req.params.id, req.userId]);
    res.json({ removed: true });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/friends/requests
router.get('/requests', authMiddleware, (req, res) => {
  try {
    const requests = all(`
      SELECT u.id, u.display_name, u.level, f.created_at
      FROM friendships f JOIN users u ON u.id = f.user_id
      WHERE f.friend_id = ? AND f.status = 'pending'
      ORDER BY f.created_at DESC
    `, [req.userId]);
    res.json({
      requests: requests.map(r => ({
        userId: r.id, displayName: r.display_name, level: r.level, sentAt: r.created_at,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
