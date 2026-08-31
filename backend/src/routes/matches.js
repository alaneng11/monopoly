/**
 * Match History Routes — مۆنۆپۆلی هەولێر
 * 
 * Lists completed games and provides deep post-match statistics.
 */

const express = require('express');
const { query, queryOne } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── User Match History ───────────────────────────────────────

router.get('/history', authMiddleware, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const matches = await query(
      'SELECT * FROM match_history ORDER BY played_at DESC LIMIT $1 OFFSET $2',
      [limit, offset]
    );

    res.json({
      matches: matches.map(m => ({
        id: m.id,
        roomCode: m.room_code,
        winnerId: m.winner_id,
        winnerName: m.winner_name,
        playerIds: typeof m.player_ids === 'string' ? JSON.parse(m.player_ids) : m.player_ids,
        playerNames: typeof m.player_names === 'string' ? JSON.parse(m.player_names) : m.player_names,
        round: m.round,
        durationSeconds: m.duration_seconds,
        finalNetWorth: m.final_net_worth,
        playedAt: m.played_at,
      })),
      page,
      limit,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Match Detail ─────────────────────────────────────────────

router.get('/:id', authMiddleware, async (req, res) => {
  try {
    const match = await queryOne('SELECT * FROM match_history WHERE id = $1', [req.params.id]);
    if (!match) return res.status(404).json({ error: 'یاری نەدۆزرایەوە.' });

    res.json({
      match: {
        id: match.id,
        roomCode: match.room_code,
        winnerId: match.winner_id,
        winnerName: match.winner_name,
        playerIds: typeof match.player_ids === 'string' ? JSON.parse(match.player_ids) : match.player_ids,
        playerNames: typeof match.player_names === 'string' ? JSON.parse(match.player_names) : match.player_names,
        round: match.round,
        durationSeconds: match.duration_seconds,
        finalNetWorth: match.final_net_worth,
        stats: typeof match.stats === 'string' ? JSON.parse(match.stats) : match.stats,
        playedAt: match.played_at,
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
