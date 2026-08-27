/**
 * Leaderboard Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { all } = require('../models/database');
const { optionalAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/weekly', optionalAuth, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const leaders = all(`
      SELECT u.id, u.display_name, u.level, l.weekly_xp, l.weekly_wins
      FROM leaderboard l JOIN users u ON u.id = l.user_id
      ORDER BY l.weekly_xp DESC LIMIT ?
    `, [limit]);
    res.json({ period: 'weekly', leaders: leaders.map((l, i) => ({
      rank: i + 1, userId: l.id, displayName: l.display_name, level: l.level,
      xp: l.weekly_xp, wins: l.weekly_wins,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/monthly', optionalAuth, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const leaders = all(`
      SELECT u.id, u.display_name, u.level, l.monthly_xp, l.monthly_wins
      FROM leaderboard l JOIN users u ON u.id = l.user_id
      ORDER BY l.monthly_xp DESC LIMIT ?
    `, [limit]);
    res.json({ period: 'monthly', leaders: leaders.map((l, i) => ({
      rank: i + 1, userId: l.id, displayName: l.display_name, level: l.level,
      xp: l.monthly_xp, wins: l.monthly_wins,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/all-time', optionalAuth, (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);
    const leaders = all(`
      SELECT id, display_name, level, xp, wins, games_played
      FROM users ORDER BY xp DESC LIMIT ?
    `, [limit]);
    res.json({ period: 'all-time', leaders: leaders.map((l, i) => ({
      rank: i + 1, userId: l.id, displayName: l.display_name, level: l.level,
      xp: l.xp, wins: l.wins, gamesPlayed: l.games_played,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
