const express = require('express');
const { queryOne, query, run } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
  try {
    const friends = await query(`SELECT u.id, u.display_name, u.level, u.avatar_url, f.status FROM friendships f JOIN users u ON (u.id = f.friend_id AND f.user_id = $1) OR (u.id = f.user_id AND f.friend_id = $1) WHERE (f.user_id = $1 OR f.friend_id = $1) AND f.status = 'accepted'`, [req.userId]);
    res.json({ friends: friends.map(f => ({ id: f.id, displayName: f.display_name, level: f.level, avatarUrl: f.avatar_url })) });
  } catch (err) { res.status(500).json({ error: 'هەڵەی ناوخۆ.' }); }
});

router.post('/add/:id', authMiddleware, async (req, res) => {
  try {
    if (req.params.id === req.userId) return res.status(400).json({ error: 'ناتوانیت خۆت هاوڕێی خۆت بکەیت.' });
    const target = await queryOne('SELECT id FROM users WHERE id = $1', [req.params.id]);
    if (!target) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    const existing = await queryOne('SELECT status FROM friendships WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)', [req.userId, req.params.id]);
    if (existing?.status === 'accepted') return res.json({ message: 'پێشتر هاوڕێن.' });
    if (existing?.status === 'pending') return res.json({ message: 'داواکاری پێشتر نێردراوە.' });
    await run('INSERT INTO friendships (user_id, friend_id, status) VALUES ($1,$2,$3)', [req.userId, req.params.id, 'pending']);
    res.status(201).json({ message: 'داواکاری نێردرا.' });
  } catch (err) { res.status(500).json({ error: 'هەڵەی ناوخۆ.' }); }
});

router.post('/accept/:id', authMiddleware, async (req, res) => {
  try {
    const request = await queryOne('SELECT * FROM friendships WHERE user_id = $1 AND friend_id = $2 AND status = $3', [req.params.id, req.userId, 'pending']);
    if (!request) return res.status(404).json({ error: 'داواکاری نەدۆزرایەوە.' });
    const now = Math.floor(Date.now()/1000);
    await run('UPDATE friendships SET status = $1, accepted_at = $2 WHERE user_id = $3 AND friend_id = $4', ['accepted', now, req.params.id, req.userId]);
    await run('INSERT INTO friendships (user_id, friend_id, status, accepted_at) VALUES ($1,$2,$3,$4)', [req.userId, req.params.id, 'accepted', now]);
    res.json({ message: 'هاوڕێ بوو! 🎉' });
  } catch (err) { res.status(500).json({ error: 'هەڵەی ناوخۆ.' }); }
});

router.post('/remove/:id', authMiddleware, async (req, res) => {
  try {
    await run('DELETE FROM friendships WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)', [req.userId, req.params.id, req.params.id]);
    res.json({ removed: true });
  } catch (err) { res.status(500).json({ error: 'هەڵەی ناوخۆ.' }); }
});

router.get('/requests', authMiddleware, async (req, res) => {
  try {
    const requests = await query('SELECT u.id, u.display_name, u.level, f.created_at FROM friendships f JOIN users u ON u.id = f.user_id WHERE f.friend_id = $1 AND f.status = $2 ORDER BY f.created_at DESC', [req.userId, 'pending']);
    res.json({ requests: requests.map(r => ({ userId: r.id, displayName: r.display_name, level: r.level, sentAt: r.created_at })) });
  } catch (err) { res.status(500).json({ error: 'هەڵەی ناوخۆ.' }); }
});

module.exports = router;
