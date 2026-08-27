/**
 * Authentication Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const bcrypt = require('bcryptjs');
const { queryOne, run } = require('../models/database');
const { generateToken, verifyToken, authMiddleware } = require('../middleware/auth');
const { generateId, sanitizeText } = require('../utils/validation');

const router = express.Router();

router.post('/register', async (req, res) => {
  try {
    const { username, password, displayName } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'ناو و وشەی نهێنی پێویستە.' });
    if (username.length < 3 || username.length > 20) return res.status(400).json({ error: 'ناو دەبێت ٣-٢٠ نووسین.' });
    if (password.length < 6) return res.status(400).json({ error: 'وشەی نهێنی دەبێت ٦+ نووسین.' });

    const existing = await queryOne('SELECT id FROM users WHERE username = $1', [username.toLowerCase()]);
    if (existing) return res.status(409).json({ error: 'ئەم ناوە هەیە پێشتر.' });

    const id = generateId();
    const hash = bcrypt.hashSync(password, 10);
    await run('INSERT INTO users (id, username, display_name, password_hash) VALUES ($1,$2,$3,$4)',
      [id, username.toLowerCase(), sanitizeText(displayName || username, 30), hash]);
    await run('INSERT INTO player_profiles (user_id) VALUES ($1)', [id]);
    await run('INSERT INTO player_statistics (user_id) VALUES ($1)', [id]);

    const token = generateToken(id);
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [id]);
    res.status(201).json({ token, user: formatUser(user) });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) return res.status(400).json({ error: 'ناو و وشەی نهێنی پێویستە.' });
    const user = await queryOne('SELECT * FROM users WHERE username = $1', [username.toLowerCase()]);
    if (!user || !user.password_hash) return res.status(401).json({ error: 'ناو یان وشەی نهێنی نادروستە.' });
    if (!bcrypt.compareSync(password, user.password_hash)) return res.status(401).json({ error: 'ناو یان وشەی نهێنی نادروستە.' });
    await run('UPDATE users SET last_login_at = $1, updated_at = $2 WHERE id = $3', [Math.floor(Date.now()/1000), Math.floor(Date.now()/1000), user.id]);
    res.json({ token: generateToken(user.id), user: formatUser(user) });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/guest', async (req, res) => {
  try {
    const id = generateId();
    const countRow = await queryOne('SELECT COUNT(*) as c FROM users');
    const guestNum = parseInt(countRow?.c || 0) + 1;
    await run('INSERT INTO users (id, username, display_name) VALUES ($1,$2,$3)',
      [id, `guest_${guestNum}`, sanitizeText(req.body?.displayName || `یاریزان ${guestNum}`, 30)]);
    await run('INSERT INTO player_profiles (user_id) VALUES ($1)', [id]);
    await run('INSERT INTO player_statistics (user_id) VALUES ($1)', [id]);
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [id]);
    res.status(201).json({ token: generateToken(id), user: formatUser(user) });
  } catch (err) {
    console.error('Guest error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/refresh', async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'توکن پێویستە.' });
    const decoded = verifyToken(token);
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [decoded.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    res.json({ token: generateToken(user.id), user: formatUser(user) });
  } catch (err) {
    res.status(401).json({ error: 'توکن نادروستە.' });
  }
});

router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await queryOne('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    const profile = await queryOne('SELECT * FROM player_profiles WHERE user_id = $1', [req.userId]);
    const stats = await queryOne('SELECT * FROM player_statistics WHERE user_id = $1', [req.userId]);
    res.json({ user: formatUser(user), profile, statistics: stats });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

function formatUser(u) {
  if (!u) return null;
  return {
    id: u.id, username: u.username, displayName: u.display_name,
    coins: u.coins, gems: u.gems, xp: u.xp, level: u.level,
    wins: u.wins, gamesPlayed: u.games_played, streak: u.streak, createdAt: u.created_at,
  };
}

module.exports = router;
module.exports.formatUser = formatUser;
