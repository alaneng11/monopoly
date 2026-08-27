/**
 * User / Profile Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { run, get, all } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { sanitizeText } = require('../utils/validation');

const router = express.Router();

// GET /api/users/:id
router.get('/:id', async (req, res) => {
  try {
    const user = get(`
      SELECT id, username, display_name, avatar_url, xp, level, wins, games_played, created_at
      FROM users WHERE id = ?
    `, [req.params.id]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    const achievements = all('SELECT achievement_id, unlocked_at FROM user_achievements WHERE user_id = ?', [req.params.id]);

    res.json({
      user: {
        id: user.id, username: user.username, displayName: user.display_name,
        avatarUrl: user.avatar_url, xp: user.xp, level: user.level,
        wins: user.wins, gamesPlayed: user.games_played, createdAt: user.created_at,
      },
      achievements: achievements.map(a => ({ id: a.achievement_id, unlockedAt: a.unlocked_at })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// PUT /api/users/me
router.put('/me', authMiddleware, async (req, res) => {
  try {
    const { displayName, avatarUrl } = req.body;
    const updates = [];
    const params = [];

    if (displayName) { updates.push('display_name = ?'); params.push(sanitizeText(displayName, 30)); }
    if (avatarUrl !== undefined) { updates.push('avatar_url = ?'); params.push(sanitizeText(avatarUrl, 200)); }

    if (updates.length === 0) return res.status(400).json({ error: 'گۆڕانکاریک بەس نییە.' });

    updates.push('updated_at = unixepoch()');
    params.push(req.userId);

    run(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, params);
    const user = get('SELECT * FROM users WHERE id = ?', [req.userId]);
    res.json({ user: formatUser(user) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/users/me/coins
router.post('/me/coins', authMiddleware, async (req, res) => {
  try {
    const { amount, reason } = req.body;
    if (typeof amount !== 'number' || amount <= 0 || amount > 100000) {
      return res.status(400).json({ error: 'بڕی دراو نادروستە.' });
    }
    const user = get('SELECT * FROM users WHERE id = ?', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    const newCoins = user.coins + amount;
    run('UPDATE users SET coins = ?, updated_at = unixepoch() WHERE id = ?', [newCoins, req.userId]);
    run('INSERT INTO transactions (from_id, to_id, amount, reason) VALUES (?, ?, ?, ?)', ['system', req.userId, amount, reason || 'reward']);

    res.json({ coins: newCoins });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/users/me/stats
router.get('/me/stats', authMiddleware, async (req, res) => {
  try {
    const user = get('SELECT * FROM users WHERE id = ?', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    const achievements = all('SELECT achievement_id FROM user_achievements WHERE user_id = ?', [req.userId])
      .map(a => a.achievement_id);

    res.json({
      stats: {
        gamesPlayed: user.games_played, wins: user.wins,
        winRate: user.games_played > 0 ? Math.round((user.wins / user.games_played) * 100) : 0,
        xp: user.xp, level: user.level, coins: user.coins, gems: user.gems,
        streak: user.streak, netWorth: user.coins + user.gems * 100,
      },
      achievements,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/users/me/achievements
router.post('/me/achievements', authMiddleware, async (req, res) => {
  try {
    const { achievementId } = req.body;
    if (!achievementId) return res.status(400).json({ error: 'ناسنامەی دەستکەوت پێویستە.' });

    const existing = get('SELECT 1 FROM user_achievements WHERE user_id = ? AND achievement_id = ?', [req.userId, achievementId]);
    if (existing) return res.json({ unlocked: false, message: 'پێشتر دەستکەوتە.' });

    run('INSERT INTO user_achievements (user_id, achievement_id) VALUES (?, ?)', [req.userId, achievementId]);
    run('UPDATE users SET coins = coins + 100, updated_at = unixepoch() WHERE id = ?', [req.userId]);

    res.json({ unlocked: true, coins: 100 });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

function formatUser(u) {
  if (!u) return null;
  return {
    id: u.id, username: u.username, displayName: u.display_name, avatarUrl: u.avatar_url,
    coins: u.coins, gems: u.gems, xp: u.xp, level: u.level,
    wins: u.wins, gamesPlayed: u.games_played, streak: u.streak, createdAt: u.created_at,
  };
}

module.exports = router;
