/**
 * Game Routes — مۆنۆپۆلی هەولێر
 * Server-authoritative: all game logic validated on backend.
 */

const express = require('express');
const { query, queryOne, run, transaction } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');
const { generateId, generateRoomCode, sanitizeText } = require('../utils/validation');
const engine = require('../services/game_engine');

const router = express.Router();

// ── Room Management ─────────────────────────────────────────

router.post('/', authMiddleware, async (req, res) => {
  try {
    const { roomName, isPublic, maxPlayers, startCash } = req.body;
    const code = generateRoomCode();
    await run(
      'INSERT INTO game_rooms (code, host_id, room_name, is_public, max_players, start_cash) VALUES ($1,$2,$3,$4,$5,$6)',
      [code, req.userId, sanitizeText(roomName || '', 30), isPublic ? 1 : 0, maxPlayers || 6, startCash || 1500]
    );
    await run(
      'INSERT INTO game_room_players (room_code, user_id, character_id, ready) VALUES ($1,$2,$3,1)',
      [code, req.userId, 'business']
    );
    const room = await getRoom(code);
    res.status(201).json({ room });
  } catch (err) {
    console.error('Create room error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/:code', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const room = await getRoom(code);
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    res.json({ room });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/join', authMiddleware, async (req, res) => {

  try {
    const code = req.params.code.toUpperCase();
    const room = await queryOne('SELECT * FROM game_rooms WHERE code = $1', [code]);
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    if (room.status !== 'lobby') return res.status(400).json({ error: 'یارییەکە دەستی پێکردووە.' });

    const countRow = await queryOne('SELECT COUNT(*) as c FROM game_room_players WHERE room_code = $1', [code]);
    if (parseInt(countRow.c) >= room.max_players) return res.status(400).json({ error: 'ژوورەکە پڕە.' });

    const existing = await queryOne('SELECT 1 FROM game_room_players WHERE room_code = $1 AND user_id = $2', [code, req.userId]);
    if (!existing) {
      await run('INSERT INTO game_room_players (room_code, user_id, character_id) VALUES ($1,$2,$3)',
        [code, req.userId, 'business']);
    }
    await run('UPDATE game_rooms SET version = version + 1, updated_at = $1 WHERE code = $2', [engine.now(), code]);
    const updatedRoom = await getRoom(code);

    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(code, { type: 'room_updated', room: updatedRoom });
    } catch (_) {}

    res.json({ room: updatedRoom });
  } catch (err) {
    console.error('Join error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/ready', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    await run('UPDATE game_room_players SET ready = $1 WHERE room_code = $2 AND user_id = $3',
      [req.body.ready ? 1 : 0, code, req.userId]);
    await run('UPDATE game_rooms SET version = version + 1, updated_at = $1 WHERE code = $2', [engine.now(), code]);
    const updatedRoom = await getRoom(code);

    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(code, { type: 'room_updated', room: updatedRoom });
    } catch (_) {}

    res.json({ room: updatedRoom });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/start', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const room = await queryOne('SELECT * FROM game_rooms WHERE code = $1', [code]);
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    if (room.host_id !== req.userId) return res.status(403).json({ error: 'تەنها میوان.' });

    const players = await query('SELECT p.*, u.display_name, u.avatar_url FROM game_room_players p JOIN users u ON u.id = p.user_id WHERE p.room_code = $1 ORDER BY p.joined_at ASC', [code]);
    if (players.length < 2) return res.status(400).json({ error: 'لانی کەم ٢ یاریزان.' });

    // Find host's index so they go first
    const hostIdx = players.findIndex(p => p.user_id === req.userId);
    const currentPlayerIndex = hostIdx >= 0 ? hostIdx : 0;

    const seed = Math.floor(Math.random() * 2147483647);
    const gameState = players.map((p, i) => ({
      id: p.user_id,
      name: p.display_name || `یاریزان ${i + 1}`,
      colorIndex: i,
      characterId: p.character_id,
      kind: 'human',
      cash: room.start_cash,
      position: 0,
      in_jail: false,
      jailTurns: 0,
      doublesInARow: 0,
      propertiesOwned: 0,
      bankrupt: false,
    }));

    await run(
      'INSERT INTO game_states (room_code, current_player_index, players, dice, phase, seed, dice_energy, max_dice_energy) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
      [code, currentPlayerIndex, JSON.stringify(gameState), JSON.stringify([1, 1]), 'awaitingRoll', seed, 10, 10]
    );

    await run('UPDATE game_rooms SET status = $1, started_at = $2, version = version + 1, updated_at = $3 WHERE code = $4',
      ['playing', engine.now(), engine.now(), code]);

    const state = await engine.getState(code);

    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(code, { type: 'game_started', roomCode: code, state });
    } catch (_) {}

    res.json({ gameStarted: true, code, state });
  } catch (err) {
    console.error('Start error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/leave', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    await run('DELETE FROM game_room_players WHERE room_code = $1 AND user_id = $2', [code, req.userId]);
    const countRow = await queryOne('SELECT COUNT(*) as c FROM game_room_players WHERE room_code = $1', [code]);
    if (parseInt(countRow.c) === 0) {
      await run('UPDATE game_rooms SET status = $1, updated_at = $2 WHERE code = $3', ['closed', engine.now(), code]);
    } else {
      const room = await queryOne('SELECT host_id FROM game_rooms WHERE code = $1', [code]);
      if (room?.host_id === req.userId) {
        const newHost = await queryOne('SELECT user_id FROM game_room_players WHERE room_code = $1 LIMIT 1', [code]);
        if (newHost) await run('UPDATE game_rooms SET host_id = $1, updated_at = $2 WHERE code = $3', [newHost.user_id, engine.now(), code]);
      }
      await run('UPDATE game_rooms SET version = version + 1, updated_at = $1 WHERE code = $2', [engine.now(), code]);
    }
    const updatedRoom = await getRoom(code);
    try {
      const { broadcastToRoom } = require('../index');
      broadcastToRoom(code, { type: 'room_updated', room: updatedRoom });
    } catch (_) {}
    res.json({ left: true });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/public', async (req, res) => {
  try {
    const rooms = await query(`
      SELECT r.code, r.room_name, r.status, r.max_players, r.start_cash,
        (SELECT COUNT(*) FROM game_room_players WHERE room_code = r.code) as player_count
      FROM game_rooms r WHERE r.is_public = 1 AND r.status = 'lobby'
      ORDER BY r.created_at DESC LIMIT 50
    `);
    res.json({ rooms: rooms.map(r => ({
      code: r.code, roomName: r.room_name, status: r.status,
      playerCount: parseInt(r.player_count), maxPlayers: r.max_players, startCash: r.start_cash,
    }))});
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/:code', authMiddleware, async (req, res) => {
  try {
    const room = await getRoom(req.params.code.toUpperCase());
    if (!room) return res.status(404).json({ error: 'ژوورەکە نەدۆزرایەوە.' });
    res.json({ room });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Server-Authoritative Game Actions ───────────────────────

router.post('/:code/roll', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.rollDice(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'dice_rolled', dice: result.dice, total: result.total, playerId: req.userId, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/move', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.movePlayer(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'player_moved', playerId: req.userId, position: result.position, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/resolve', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.resolveLanding(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'landing_resolved', playerId: req.userId, result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/buy', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.buyProperty(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'property_bought', playerId: req.userId, ...result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/upgrade', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { tileIndex } = req.body;
    const result = await engine.upgradeProperty(code, req.userId, tileIndex);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'property_upgraded', playerId: req.userId, ...result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/end-turn', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.endTurn(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'turn_ended', playerId: req.userId, ...result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/auction/bid', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { amount } = req.body;
    const result = await engine.placeAuctionBid(code, req.userId, parseInt(amount));
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'auction_updated', auction: result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/auction/pass', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const result = await engine.passAuctionBid(code, req.userId);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'auction_updated', auction: result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/trade/propose', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { toPlayerId, fromMoney, toMoney, fromTileIndices, toTileIndices } = req.body;
    const result = await engine.proposeTrade(code, req.userId, toPlayerId, fromMoney, toMoney, fromTileIndices, toTileIndices);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'trade_updated', trade: result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/trade/respond', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { accept } = req.body;
    const result = await engine.respondTrade(code, req.userId, !!accept);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'trade_resolved', result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/mortgage', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { tileIndex } = req.body;
    const result = await engine.mortgageProperty(code, req.userId, tileIndex);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'property_mortgaged', ...result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/unmortgage', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const { tileIndex } = req.body;
    const result = await engine.unmortgageProperty(code, req.userId, tileIndex);
    const state = await engine.getState(code);
    try { require('../index').broadcastToRoom(code, { type: 'property_unmortgaged', ...result, state }); } catch (_) {}
    res.json(result);
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/spectate', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    await run('INSERT INTO spectators (room_code, user_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [code, req.userId]);
    const state = await engine.getState(code);
    res.json({ spectating: true, state });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/:code/transactions', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const txs = await query('SELECT * FROM transactions WHERE room_code = $1 ORDER BY created_at DESC LIMIT 50', [code]);
    res.json({ transactions: txs });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.get('/:code/state', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const state = await engine.getState(code);
    if (!state) return res.status(404).json({ error: 'یاری نەدۆزرایەوە.' });
    res.json(state);
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/:code/spectate', authMiddleware, async (req, res) => {
  try {
    const code = req.params.code.toUpperCase();
    const state = await engine.getState(code);
    if (!state) return res.status(404).json({ error: 'ژوور نەدۆزرایەوە.' });
    try {
      await run('INSERT INTO spectators (room_code, user_id, joined_at) VALUES ($1,$2,$3)', [code, req.userId, Math.floor(Date.now() / 1000)]);
    } catch (_) {}
    res.json({ success: true, roomCode: code, state });
  } catch (err) {
    res.status(err.status || 400).json({ error: err.message || 'هەڵەی ناوخۆ.' });
  }
});


// ── Helper ──────────────────────────────────────────────────

async function getRoom(code) {
  const room = await queryOne('SELECT * FROM game_rooms WHERE code = $1', [code]);
  if (!room) return null;
  const players = await query('SELECT p.*, u.display_name, u.avatar_url FROM game_room_players p JOIN users u ON u.id = p.user_id WHERE p.room_code = $1 ORDER BY p.joined_at ASC', [code]);
  return {
    code: room.code, hostId: room.host_id, roomName: room.room_name,
    status: room.status, maxPlayers: room.max_players, isPublic: !!room.is_public,
    startCash: room.start_cash, version: room.version,
    players: players.map(p => ({
      id: p.user_id,
      name: p.display_name || 'یاریزان',
      avatarUrl: p.avatar_url,
      characterId: p.character_id,
      ready: !!p.ready,
      connected: !!p.connected,
    })),
  };
}

module.exports = router;
