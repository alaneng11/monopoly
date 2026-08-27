/**
 * Game Room & State Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const { run, get, all } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { generateId, generateRoomCode, sanitizeText, validateDice } = require('../utils/validation');

const router = express.Router();

// POST /api/rooms — Create room
router.post('/', authMiddleware, (req, res) => {
  try {
    const { roomName, isPublic, maxPlayers, startCash } = req.body;
    const code = generateRoomCode();

    run(
      'INSERT INTO game_rooms (code, host_id, room_name, is_public, max_players, start_cash) VALUES (?, ?, ?, ?, ?, ?)',
      [code, req.userId, sanitizeText(roomName || '', 30), isPublic ? 1 : 0, maxPlayers || 6, startCash || 1500]
    );
    run('INSERT INTO game_room_players (room_code, user_id, character_id, ready) VALUES (?, ?, ?, 1)',
      [code, req.userId, 'business']);

    res.status(201).json({ room: getRoom(code) });
  } catch (err) {
    console.error('Create room error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ — ژوور دروست نەبوو.' });
  }
});

// POST /api/rooms/:code/join
router.post('/:code/join', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const room = get('SELECT * FROM game_rooms WHERE code = ?', [code]);
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    if (room.status !== 'lobby') return res.status(400).json({ error: 'یارییەکە دەستی پێکردووە.' });

    const countRow = get('SELECT COUNT(*) as c FROM game_room_players WHERE room_code = ?', [code]);
    if (countRow.c >= room.max_players) return res.status(400).json({ error: 'ژوورەکە پڕە.' });

    const existing = get('SELECT 1 FROM game_room_players WHERE room_code = ? AND user_id = ?', [code, req.userId]);
    if (!existing) {
      run('INSERT INTO game_room_players (room_code, user_id, character_id) VALUES (?, ?, ?)',
        [code, req.userId, 'business']);
    }

    run('UPDATE game_rooms SET version = version + 1, updated_at = unixepoch() WHERE code = ?', [code]);
    res.json({ room: getRoom(code) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/rooms/:code/ready
router.post('/:code/ready', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { ready } = req.body;
    run('UPDATE game_room_players SET ready = ? WHERE room_code = ? AND user_id = ?',
      [ready ? 1 : 0, code, req.userId]);
    run('UPDATE game_rooms SET version = version + 1, updated_at = unixepoch() WHERE code = ?', [code]);
    res.json({ room: getRoom(code) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/rooms/:code/start
router.post('/:code/start', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const room = get('SELECT * FROM game_rooms WHERE code = ?', [code]);
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    if (room.host_id !== req.userId) return res.status(403).json({ error: 'تەنها میوان دەتوانێت یاری دەستپێبکات.' });

    const players = all('SELECT * FROM game_room_players WHERE room_code = ?', [code]);
    if (players.length < 2) return res.status(400).json({ error: 'لانی کەم ٢ یاریزان پێویستە.' });

    const gameState = initializeGameState(players, room.start_cash);

    run(
      'INSERT OR REPLACE INTO game_states (room_code, players, dice, phase, seed, version) VALUES (?, ?, ?, ?, ?, 1)',
      [code, JSON.stringify(gameState.players), JSON.stringify([1, 1]), 'awaitingRoll', gameState.seed]
    );
    run('UPDATE game_rooms SET status = ?, version = version + 1, updated_at = unixepoch() WHERE code = ?',
      ['playing', code]);

    res.json({ gameStarted: true, code });
  } catch (err) {
    console.error('Start game error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ — یاری دەست نەبوو.' });
  }
});

// POST /api/rooms/:code/leave
router.post('/:code/leave', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    run('DELETE FROM game_room_players WHERE room_code = ? AND user_id = ?', [code, req.userId]);

    const countRow = get('SELECT COUNT(*) as c FROM game_room_players WHERE room_code = ?', [code]);
    if (countRow.c === 0) {
      run('UPDATE game_rooms SET status = ?, updated_at = unixepoch() WHERE code = ?', ['closed', code]);
    } else {
      const room = get('SELECT host_id FROM game_rooms WHERE code = ?', [code]);
      if (room && room.host_id === req.userId) {
        const newHost = get('SELECT user_id FROM game_room_players WHERE room_code = ? LIMIT 1', [code]);
        if (newHost) run('UPDATE game_rooms SET host_id = ?, updated_at = unixepoch() WHERE code = ?', [newHost.user_id, code]);
      }
      run('UPDATE game_rooms SET version = version + 1, updated_at = unixepoch() WHERE code = ?', [code]);
    }
    res.json({ left: true });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/rooms/public
router.get('/public', async (req, res) => {
  try {
    const rooms = all(`
      SELECT r.code, r.room_name, r.status, r.max_players, r.start_cash,
        (SELECT COUNT(*) FROM game_room_players WHERE room_code = r.code) as player_count
      FROM game_rooms r
      WHERE r.is_public = 1 AND r.status = 'lobby'
      ORDER BY r.created_at DESC
      LIMIT 50
    `);
    res.json({ rooms: rooms.map(r => ({
      code: r.code, roomName: r.room_name, status: r.status,
      playerCount: r.player_count, maxPlayers: r.max_players, startCash: r.start_cash,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/games/:code/roll — Server generates dice
router.post('/:code/roll', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const gs = get('SELECT * FROM game_states WHERE room_code = ?', [code]);
    if (!gs) return res.status(404).json({ error: 'یاری نەدۆزرایەوە.' });

    const players = JSON.parse(gs.players);
    const current = players[gs.current_player_index];
    if (!current || current.id !== req.userId) return res.status(403).json({ error: 'نەک ئێستای تۆ.' });
    if (gs.phase !== 'awaitingRoll') return res.status(400).json({ error: 'ئێستا کاتی داوەدان نییە.' });

    const d1 = Math.floor(Math.random() * 6) + 1;
    const d2 = Math.floor(Math.random() * 6) + 1;

    run(
      `UPDATE game_states SET dice = ?, phase = 'rolling', dice_energy = dice_energy - 1,
       version = version + 1, updated_at = unixepoch() WHERE room_code = ?`,
      [JSON.stringify([d1, d2]), code]
    );

    res.json({ dice: [d1, d2], total: d1 + d2 });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// GET /api/games/:code/state
router.get('/:code/state', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const gs = get('SELECT * FROM game_states WHERE room_code = ?', [code]);
    if (!gs) return res.status(404).json({ error: 'یاری نەدۆزرایەوە.' });

    res.json({
      round: gs.round, currentPlayerIndex: gs.current_player_index, phase: gs.phase,
      dice: JSON.parse(gs.dice || '[1,1]'), players: JSON.parse(gs.players || '[]'),
      tiles: JSON.parse(gs.tiles || '{}'), freeCoins: gs.free_coins, winnerId: gs.winner_id,
      diceMultiplier: gs.dice_multiplier, diceEnergy: gs.dice_energy, version: gs.version,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// POST /api/games/:code/end-turn
router.post('/:code/end-turn', authMiddleware, (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const gs = get('SELECT * FROM game_states WHERE room_code = ?', [code]);
    if (!gs) return res.status(404).json({ error: 'یاری نەدۆزرایەوە.' });

    const players = JSON.parse(gs.players);
    const current = players[gs.current_player_index];
    if (!current || current.id !== req.userId) return res.status(403).json({ error: 'نەک ئێستای تۆ.' });

    let nextIndex = (gs.current_player_index + 1) % players.length;
    const newRound = nextIndex === 0 ? gs.round + 1 : gs.round;

    run(
      `UPDATE game_states SET current_player_index = ?, round = ?, phase = 'awaitingRoll',
       dice_multiplier = 1, dice_energy = MIN(dice_energy + 1, 10),
       version = version + 1, updated_at = unixepoch() WHERE room_code = ?`,
      [nextIndex, newRound, code]
    );

    res.json({ success: true, nextPlayerIndex: nextIndex, round: newRound });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

function getRoom(code) {
  const room = get('SELECT * FROM game_rooms WHERE code = ?', [code]);
  if (!room) return null;
  const players = all('SELECT * FROM game_room_players WHERE room_code = ?', [code]);
  return {
    code: room.code, hostId: room.host_id, roomName: room.room_name,
    status: room.status, maxPlayers: room.max_players, isPublic: !!room.is_public,
    startCash: room.start_cash, version: room.version,
    players: players.map(p => ({
      id: p.user_id, characterId: p.character_id, ready: !!p.ready, connected: !!p.connected,
    })),
  };
}

function initializeGameState(players, startCash) {
  const seed = Math.floor(Math.random() * 2147483647);
  return {
    seed,
    players: players.map((p, i) => ({
      id: p.user_id, name: p.user_id, colorIndex: i, characterId: p.character_id,
      kind: 'human', cash: startCash, position: 0, inJail: false,
      jailTurns: 0, doublesInARow: 0, propertiesOwned: 0, bankrupt: false,
    })),
  };
}

module.exports = router;
