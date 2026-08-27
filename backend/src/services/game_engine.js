/**
 * Server-Authoritative Game Engine — مۆنۆپۆلی هەولێر
 *
 * ALL game logic is validated and executed on the server.
 * The client only sends action requests.
 */

const { query, queryOne, run, transaction } = require('../models/database');
const { generateId, validateDice } = require('../utils/validation');

// ── Board Definition (40 tiles) ─────────────────────────────

const BOARD = require('../../board_data.json');

// ── Helpers ─────────────────────────────────────────────────

function now() { return Math.floor(Date.now() / 1000); }

function randomDice() {
  return [Math.floor(Math.random() * 6) + 1, Math.floor(Math.random() * 6) + 1];
}

/** Parse SQLite TEXT fields that are actually JSON */
function parseState(gs) {
  if (!gs) return gs;
  if (typeof gs.players === 'string') gs.players = JSON.parse(gs.players);
  if (typeof gs.dice === 'string') gs.dice = JSON.parse(gs.dice);
  if (typeof gs.active_event === 'string' && gs.active_event) gs.active_event = JSON.parse(gs.active_event);
  if (typeof gs.pending_trade === 'string' && gs.pending_trade) gs.pending_trade = JSON.parse(gs.pending_trade);
  if (typeof gs.auction === 'string' && gs.auction) gs.auction = JSON.parse(gs.auction);
  return gs;
}

function advancePlayer(players, fromIndex) {
  let next = (fromIndex + 1) % players.length;
  let guard = 0;
  while (players[next]?.bankrupt && guard++ < players.length) {
    next = (next + 1) % players.length;
  }
  return next;
}

function computeRent(tile, level, eventMult = 1.0) {
  const base = tile.rentByLevel?.[level] || tile.rentByLevel?.[0] || 0;
  const monopolyBonus = level === 0 ? 1 : 1;
  return Math.round(base * monopolyBonus * eventMult);
}

// ── Roll Dice ───────────────────────────────────────────────

async function rollDice(roomCode, userId) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs) throw { code: 'NO_GAME', message: 'یاری نەدۆزرایەوە.' };

    const players = gs.players;
    const current = players[gs.current_player_index];
    if (!current || current.id !== userId) throw { code: 'WRONG_TURN', message: 'نەک ئێستای تۆ.' };
    if (gs.phase !== 'awaitingRoll') throw { code: 'BAD_PHASE', message: 'ئێستا کاتی داوەدان نییە.' };

    // Energy check
    if (gs.dice_energy <= 0) throw { code: 'NO_ENERGY', message: 'ئێرژی بەرد تەواوبووە!' };

    // Generate dice server-side
    const [d1, d2] = randomDice();
    const doubles = d1 === d2;
    const newDoubles = doubles ? (current.doubles_in_a_row || 0) + 1 : 0;

    // Deduct energy
    const newEnergy = Math.max(0, gs.dice_energy - 1);

    // Three doubles = jail
    if (newDoubles >= 3) {
      const updatedPlayers = players.map(p =>
        p.id === userId ? { ...p, in_jail: true, jail_turns: 0, doubles_in_a_row: 0, position: 10 } : p
      );
      await db.run(
        'UPDATE game_states SET players = $1, dice = $2, phase = $3, dice_energy = $4, state_version = state_version + 1, updated_at = $5 WHERE room_code = $6',
        [JSON.stringify(updatedPlayers), JSON.stringify([d1, d2]), 'endTurn', newEnergy, now(), roomCode]
      );
      return { dice: [d1, d2], total: d1 + d2, jail: true };
    }

    // Update players with doubles count
    const updatedPlayers = players.map(p =>
      p.id === userId ? { ...p, doubles_in_a_row: newDoubles } : p
    );

    await db.run(
      'UPDATE game_states SET players = $1, dice = $2, phase = $3, dice_energy = $4, state_version = state_version + 1, updated_at = $5 WHERE room_code = $6',
      [JSON.stringify(updatedPlayers), JSON.stringify([d1, d2]), 'rolling', newEnergy, now(), roomCode]
    );

    // Track dice roll
    try {
      await db.run(
        'UPDATE player_statistics SET dice_rolled = dice_rolled + 1 WHERE user_id = $1',
        [userId]
      );
    } catch (_) {}

    return { dice: [d1, d2], total: d1 + d2, jail: false };
  });
}

// ── Move Player ─────────────────────────────────────────────

async function movePlayer(roomCode, userId) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs) throw { code: 'NO_GAME', message: 'یاری نەدۆزرایەوە.' };

    if (gs.phase !== 'rolling' && gs.phase !== 'moving') throw { code: 'BAD_PHASE', message: 'دۆخی جوڵان چالاک نییە.' };

    const players = gs.players;
    const idx = gs.current_player_index;
    const current = players[idx];
    if (!current || current.id !== userId) throw { code: 'WRONG_TURN', message: 'نەک ئێستای تۆ.' };

    const steps = (gs.dice || [1, 1]).reduce((a, b) => a + b, 0);
    const boardLen = 40;
    const from = current.position || 0;
    const to = (from + steps) % boardLen;
    const passedStart = steps > 0 && (from + steps) >= boardLen;

    let cash = current.cash || 0;
    let txs = [];

    if (passedStart) {
      const salary = 200 * (gs.dice_multiplier || 1);
      cash += salary;
      txs.push({
        from_id: 'bank', to_id: userId, amount: salary,
        reason: 'salary', room_code: roomCode
      });
    }

    const updatedPlayers = players.map(p =>
      p.id === userId ? { ...p, position: to, cash } : p
    );

    await db.run(
      'UPDATE game_states SET players = $1, phase = $2, state_version = state_version + 1, updated_at = $3 WHERE room_code = $4',
      [JSON.stringify(updatedPlayers), 'landing', now(), roomCode]
    );

    // Record salary transactions
    for (const tx of txs) {
      await db.run(
        'INSERT INTO transactions (room_code, from_id, to_id, amount, reason) VALUES ($1,$2,$3,$4,$5)',
        [tx.room_code, tx.from_id, tx.to_id, tx.amount, tx.reason]
      );
    }

    return { position: to, steps, passedStart, salary: txs[0]?.amount || 0 };
  });
}

// ── Buy Property ────────────────────────────────────────────

async function buyProperty(roomCode, userId) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs) throw { code: 'NO_GAME', message: 'یاری نەدۆزرایەوە.' };
    if (gs.phase !== 'propertyDecision') throw { code: 'BAD_PHASE', message: 'دۆخی بڕیار چالاک نییە.' };

    const players = gs.players;
    const current = players[gs.current_player_index];
    if (!current || current.id !== userId) throw { code: 'WRONG_TURN', message: 'نەک ئێستای تۆ.' };

    const tileIdx = current.position;
    const tile = BOARD[tileIdx];
    if (!tile || !tile.isBuyable) throw { code: 'NOT_BUYABLE', message: 'ئەم خانەیە ناکڕدرێت.' };

    // Check not already owned
    const existing = await db.queryOne('SELECT 1 FROM properties WHERE room_code = $1 AND tile_index = $2', [roomCode, tileIdx]);
    if (existing) throw { code: 'OWNED', message: 'ئەم خانەیە خاوەنی هەیە.' };

    const price = tile.price;
    if (current.cash < price) throw { code: 'INSUFFICIENT', message: 'دراوت بەس نییە.' };

    // Deduct money
    const updatedPlayers = players.map(p =>
      p.id === userId ? { ...p, cash: p.cash - price, properties_owned: (p.properties_owned || 0) + 1 } : p
    );

    // Record property
    await db.run(
      'INSERT INTO properties (room_code, tile_index, owner_id, level, mortgaged) VALUES ($1,$2,$3,0,0)',
      [roomCode, tileIdx, userId]
    );

    // Update game state
    await db.run(
      'UPDATE game_states SET players = $1, phase = $2, dice_energy = MIN(dice_energy + 1, max_dice_energy), state_version = state_version + 1, updated_at = $3 WHERE room_code = $4',
      [JSON.stringify(updatedPlayers), 'endTurn', now(), roomCode]
    );

    // Record transaction
    await db.run(
      'INSERT INTO transactions (room_code, from_id, to_id, amount, reason, metadata) VALUES ($1,$2,$3,$4,$5,$6)',
      [roomCode, userId, 'bank', price, 'purchase', JSON.stringify({ tile_index: tileIdx })]
    );

    // Track stats
    await db.run(
      'UPDATE player_statistics SET properties_purchased = properties_purchased + 1, total_money_spent = total_money_spent + $1 WHERE user_id = $2',
      [price, userId]
    );

    return { tileIndex: tileIdx, price, name: tile.name };
  });
}

// ── Upgrade Property ────────────────────────────────────────

async function upgradeProperty(roomCode, userId, tileIndex) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs) throw { code: 'NO_GAME', message: 'یاری نەدۆزرایەوە.' };

    const prop = await db.queryOne('SELECT * FROM properties WHERE room_code = $1 AND tile_index = $2', [roomCode, tileIndex]);
    if (!prop) throw { code: 'NOT_OWNED', message: 'خانەکە خاوەن نییە.' };
    if (prop.owner_id !== userId) throw { code: 'NOT_OWNER', message: 'تۆ خاوەنی نیت.' };
    if (prop.mortgaged) throw { code: 'MORTGAGED', message: 'خانەکە بارمتەیە.' };

    const tile = BOARD[tileIndex];
    if (!tile || tile.isStation) throw { code: 'NOT_UPGRADABLE', message: 'ناتوانێت بەرز بکرێتەوە.' };
    if (prop.level >= (tile.maxLevel || 5)) throw { code: 'MAX_LEVEL', message: 'گەیشتووەتە بەرزترین ئاست.' };

    const cost = tile.upgradeCost;
    const current = gs.players.find(p => p.id === userId);
    if (current.cash < cost) throw { code: 'INSUFFICIENT', message: 'دراوت بەس نییە.' };

    // Update property level
    await db.run(
      'UPDATE properties SET level = level + 1 WHERE room_code = $1 AND tile_index = $2',
      [roomCode, tileIndex]
    );

    // Deduct money
    const updatedPlayers = gs.players.map(p =>
      p.id === userId ? { ...p, cash: p.cash - cost } : p
    );
    await db.run(
      'UPDATE game_states SET players = $1, state_version = state_version + 1, updated_at = $2 WHERE room_code = $3',
      [JSON.stringify(updatedPlayers), now(), roomCode]
    );

    // Record transaction
    await db.run(
      'INSERT INTO transactions (room_code, from_id, to_id, amount, reason, metadata) VALUES ($1,$2,$3,$4,$5,$6)',
      [roomCode, userId, 'bank', cost, 'upgrade', JSON.stringify({ tile_index: tileIndex, new_level: prop.level + 1 })]
    );

    return { tileIndex, newLevel: prop.level + 1, cost };
  });
}

// ── End Turn ────────────────────────────────────────────────

async function endTurn(roomCode, userId) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs) throw { code: 'NO_GAME', message: 'یاری نەدۆزرایەوە.' };
    if (gs.phase !== 'endTurn') throw { code: 'BAD_PHASE', message: 'دۆخی کۆتایی سووڕ چالاک نییە.' };

    const players = gs.players;
    const current = players[gs.current_player_index];
    if (!current || current.id !== userId) throw { code: 'WRONG_TURN', message: 'نەک ئێستای تۆ.' };

    // Regenerate energy
    let energy = Math.min(gs.dice_energy + (gs.energy_regen_rate || 1), gs.max_dice_energy || 10);

    // Doubles = extra turn
    if ((current.doubles_in_a_row || 0) > 0 && !current.in_jail && !current.bankrupt) {
      await db.run(
        'UPDATE game_states SET dice_energy = $1, dice_multiplier = 1, state_version = state_version + 1, updated_at = $2 WHERE room_code = $3',
        [energy, now(), roomCode]
      );
      return { extraTurn: true, nextPlayerIndex: gs.current_player_index };
    }

    // Advance to next player
    const nextIdx = advancePlayer(players, gs.current_player_index);
    const newRound = nextIdx === 0 ? gs.round + 1 : gs.round;

    // Check game over
    const alive = players.filter(p => !p.bankrupt);
    if (alive.length <= 1) {
      await db.run(
        'UPDATE game_states SET phase = $1, winner_id = $2, state_version = state_version + 1, updated_at = $3 WHERE room_code = $4',
        ['gameOver', alive[0]?.id || '', now(), roomCode]
      );
      return { gameOver: true, winnerId: alive[0]?.id };
    }

    await db.run(
      'UPDATE game_states SET current_player_index = $1, round = $2, phase = $3, dice_multiplier = 1, dice_energy = $4, state_version = state_version + 1, updated_at = $5 WHERE room_code = $6',
      [nextIdx, newRound, 'awaitingRoll', energy, now(), roomCode]
    );

    return { extraTurn: false, nextPlayerIndex: nextIdx, round: newRound };
  });
}

// ── Get Game State ──────────────────────────────────────────

async function getState(roomCode) {
  const gs = parseState(await queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
  if (!gs) return null;

  // Get property ownerships
  const props = await query('SELECT * FROM properties WHERE room_code = $1', [roomCode]);
  const tiles = {};
  for (const p of props) {
    tiles[p.tile_index] = {
      tileIndex: p.tile_index,
      ownerId: p.owner_id,
      level: p.level,
      mortgaged: !!p.mortgaged,
    };
  }

  return {
    roomCode: gs.room_code,
    round: gs.round,
    currentPlayerIndex: gs.current_player_index,
    phase: gs.phase,
    dice: gs.dice,
    players: gs.players,
    tiles,
    freeCoins: gs.free_coins,
    winnerId: gs.winner_id,
    diceMultiplier: gs.dice_multiplier,
    diceEnergy: gs.dice_energy,
    maxDiceEnergy: gs.max_dice_energy,
    activeEvent: gs.active_event,
    pendingTrade: gs.pending_trade,
    auction: gs.auction,
    stateVersion: gs.state_version,
  };
}

// ── Chat ────────────────────────────────────────────────────

async function sendChatMessage(roomCode, userId, text, emoji) {
  const user = await queryOne('SELECT display_name FROM users WHERE id = $1', [userId]);
  const id = generateId();
  await run(
    'INSERT INTO game_chat_messages (id, game_room_id, sender_id, sender_name, text, emoji, is_emoji, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
    [id, roomCode, userId, user?.display_name || 'یاریزان', text || '', emoji || null, emoji ? 1 : 0, now()]
  );
  return {
    id, senderId: userId, senderName: user?.display_name || 'یاریزان',
    text: text || '', emoji: emoji || null, isEmoji: !!emoji, timestamp: now(), gameRoomId: roomCode,
  };
}

// ── Resolve Landing ─────────────────────────────────────────

async function resolveLanding(roomCode, userId) {
  return transaction(async (db) => {
    const gs = parseState(await db.queryOne('SELECT * FROM game_states WHERE room_code = $1', [roomCode]));
    if (!gs || gs.phase !== 'landing') return { phase: gs?.phase || 'unknown' };

    const current = gs.players[gs.current_player_index];
    if (!current || current.id !== userId) throw { code: 'WRONG_TURN', message: 'نەک ئێستای تۆ.' };

    const tileIdx = current.position;
    const tile = BOARD[tileIdx];
    if (!tile) return { phase: 'endTurn' };

    // Corner tiles
    if (tile.type === 'corner') {
      if (tile.corner === 'start') {
        // Already handled in movePlayer (salary)
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
        return { phase: 'endTurn' };
      }
      if (tile.corner === 'goToJail') {
        const updatedPlayers = gs.players.map(p =>
          p.id === userId ? { ...p, in_jail: true, jail_turns: 0, position: 10, doubles_in_a_row: 0 } : p
        );
        await db.run('UPDATE game_states SET players = $1, phase = $2, updated_at = $3 WHERE room_code = $4',
          [JSON.stringify(updatedPlayers), 'endTurn', now(), roomCode]);
        return { phase: 'endTurn', jail: true };
      }
      await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
      return { phase: 'endTurn' };
    }

    // Tax
    if (tile.type === 'tax') {
      const tax = tile.taxAmount || 200;
      if (current.cash < tax) {
        // Bankruptcy handling would go here
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
        return { phase: 'endTurn', tax };
      }
      const updatedPlayers = gs.players.map(p =>
        p.id === userId ? { ...p, cash: p.cash - tax } : p
      );
      await db.run('UPDATE game_states SET players = $1, phase = $2, updated_at = $3 WHERE room_code = $4',
        [JSON.stringify(updatedPlayers), 'endTurn', now(), roomCode]);
      await db.run('INSERT INTO transactions (room_code, from_id, to_id, amount, reason) VALUES ($1,$2,$3,$4,$5)',
        [roomCode, userId, 'bank', tax, 'tax']);
      return { phase: 'endTurn', tax };
    }

    // Chance / Event cards
    if (tile.type === 'chance' || tile.type === 'event') {
      await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['cardEvent', now(), roomCode]);
      return { phase: 'cardEvent', tileIndex: tileIdx, type: tile.type };
    }

    // Property / Station
    if (tile.type === 'property' || tile.type === 'station') {
      const prop = await db.queryOne('SELECT * FROM properties WHERE room_code = $1 AND tile_index = $2', [roomCode, tileIdx]);

      if (!prop) {
        // Unowned — decision phase
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['propertyDecision', now(), roomCode]);
        return { phase: 'propertyDecision', tileIndex: tileIdx, price: tile.price, name: tile.name };
      }

      if (prop.owner_id === userId) {
        // Own property — collect income
        const income = tile.maintenance + (prop.level * 5);
        if (income > 0) {
          const updatedPlayers = gs.players.map(p =>
            p.id === userId ? { ...p, cash: p.cash + income } : p
          );
          await db.run('UPDATE game_states SET players = $1, phase = $2, updated_at = $3 WHERE room_code = $4',
            [JSON.stringify(updatedPlayers), 'endTurn', now(), roomCode]);
          await db.run('INSERT INTO transactions (room_code, from_id, to_id, amount, reason) VALUES ($1,$2,$3,$4,$5)',
            [roomCode, 'bank', userId, income, 'income']);
          return { phase: 'endTurn', income };
        }
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
        return { phase: 'endTurn' };
      }

      if (prop.mortgaged) {
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
        return { phase: 'endTurn', mortgaged: true };
      }

      // Pay rent
      const rent = computeRent(tile, prop.level);
      if (rent <= 0) {
        await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
        return { phase: 'endTurn' };
      }

      const updatedPlayers = gs.players.map(p => {
        if (p.id === userId) return { ...p, cash: p.cash - rent };
        if (p.id === prop.owner_id) return { ...p, cash: p.cash + rent };
        return p;
      });

      await db.run('UPDATE game_states SET players = $1, phase = $2, updated_at = $3 WHERE room_code = $4',
        [JSON.stringify(updatedPlayers), 'endTurn', now(), roomCode]);

      await db.run('INSERT INTO transactions (room_code, from_id, to_id, amount, reason, metadata) VALUES ($1,$2,$3,$4,$5,$6)',
        [roomCode, userId, prop.owner_id, rent, 'rent', JSON.stringify({ tile_index: tileIdx })]);

      // Update rent collected stat
      await db.run(
        'UPDATE player_statistics SET rent_collected = rent_collected + $1 WHERE user_id = $2',
        [rent, prop.owner_id]
      ).catch(() => {});

      return { phase: 'endTurn', rent, paidTo: prop.owner_id };
    }

    await db.run('UPDATE game_states SET phase = $1, updated_at = $2 WHERE room_code = $3', ['endTurn', now(), roomCode]);
    return { phase: 'endTurn' };
  });
}

module.exports = {
  rollDice, movePlayer, buyProperty, upgradeProperty,
  endTurn, getState, sendChatMessage, resolveLanding,
  BOARD, now, randomDice,
};
