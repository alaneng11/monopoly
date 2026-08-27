/**
 * User / Profile Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { queryOne, query, run } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { sanitizeText } = require('../utils/validation');

const router = express.Router();

router.get('/:id', async (req, res) => {
  try {
    const user = await queryOne('SELECT id, username, display_name, avatar_url, xp, level, wins, games_played, created_at FROM users WHERE id = $1', [req.params.id]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    const achievements = await query('SELECT achievement_id, unlocked_at FROM user_achievements WHERE user_id = $1', [req.params.id]);
    res.json({ user: formatUser(user), achievements: achievements.map(a => ({ id: a.achievement_id, unlockedAt: a.unlocked_at })) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.put('/me', authMiddleware, async (req, res) => {
  try {
    const { displayName, avatarUrl } = req.body;
    const updates = [];
    const params = [];
    if (displayName) { updates.push('display_name = $' + (params.length + 1)); params.push(sanitizeText(displayName, 30)); }
    if (avatarUrl !== undefined) { updates.push('avatar_url = $' + (params.length + 1)); params.push(sanitizeText(avatarUrl, 200)); }
    if (updates.length === 0) return res.status(400).json({ error: 'گۆڕانکاریک بەس نییە.' });
    updates.push('updated_at = $' + (params.length + 1)); params.push(Math.floor(Date.now()/1000));
    params.push(req.userId);
    await run(`UPDATE users SET ${updates.join(', ')} WHERE id = $${params.length}`, params);
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.userId]);
    res.json({ user: formatUser(user) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/me/stats', authMiddleware, async (req, res) => {
  try {
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    const stats = await queryOne('SELECT * FROM player_statistics WHERE user_id = $1', [req.userId]);
    const achievements = (await query('SELECT achievement_id FROM user_achievements WHERE user_id = $1', [req.userId])).map(a => a.achievement_id);
    res.json({
      stats: { gamesPlayed: user.games_played, wins: user.wins, xp: user.xp, level: user.level, coins: user.coins, gems: user.gems, streak: user.streak, ...stats },
      achievements,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/me/achievements', authMiddleware, async (req, res) => {
  try {
    const { achievementId } = req.body;
    if (!achievementId) return res.status(400).json({ error: 'ناسنامەی پێویستە.' });
    const existing = await queryOne('SELECT 1 FROM user_achievements WHERE user_id = $1 AND achievement_id = $2', [req.userId, achievementId]);
    if (existing) return res.json({ unlocked: false });
    await run('INSERT INTO user_achievements (user_id, achievement_id) VALUES ($1,$2)', [req.userId, achievementId]);
    await run('UPDATE users SET coins = coins + 100, updated_at = $1 WHERE id = $2', [Math.floor(Date.now()/1000), req.userId]);
    res.json({ unlocked: true, coins: 100 });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

function formatUser(u) {
  if (!u) return null;
  return { id: u.id, username: u.username, displayName: u.display_name, avatarUrl: u.avatar_url, coins: u.coins, gems: u.gems, xp: u.xp, level: u.level, wins: u.wins, gamesPlayed: u.games_played, streak: u.streak, createdAt: u.created_at };
}

module.exports = router;
