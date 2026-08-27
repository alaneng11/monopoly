/**
 * Authentication Routes — مۆنۆپۆلی هەولێر
 */

const express = require('express');
const bcrypt = require('bcryptjs');
const { getDb, run, get, all } = require('../models/database');
const { generateToken, verifyToken, authMiddleware } = require('../middleware/auth');
const { generateId, sanitizeText } = require('../utils/validation');

const router = express.Router();

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { username, password, displayName } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'ناو و وشەی نهێنی پێویستە.' });
    }
    if (username.length < 3 || username.length > 20) {
      return res.status(400).json({ error: 'ناو دەبێت لە ٣-٢٠ نووسین پێکەوە بێت.' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'وشەی نهێنی دەبێت لە ٦ نووسین زیاتر بێت.' });
    }

    const existing = get('SELECT id FROM users WHERE username = ?', [username.toLowerCase()]);
    if (existing) {
      return res.status(409).json({ error: 'ئەم ناوە هەیە پێشتر.' });
    }

    const id = generateId();
    const hash = bcrypt.hashSync(password, 10);
    const name = sanitizeText(displayName || username, 30);

    run(
      'INSERT INTO users (id, username, display_name, password_hash) VALUES (?, ?, ?, ?)',
      [id, username.toLowerCase(), name, hash]
    );

    const token = generateToken(id);
    const user = get('SELECT * FROM users WHERE id = ?', [id]);

    res.status(201).json({ token, user: formatUser(user) });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ — دوبارە هەوڵ بدە.' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'ناو و وشەی نهێنی پێویستە.' });
    }

    const user = get('SELECT * FROM users WHERE username = ?', [username.toLowerCase()]);
    if (!user || !user.password_hash) {
      return res.status(401).json({ error: 'ناو یان وشەی نهێنی نادروستە.' });
    }

    if (!bcrypt.compareSync(password, user.password_hash)) {
      return res.status(401).json({ error: 'ناو یان وشەی نهێنی نادروستە.' });
    }

    run('UPDATE users SET last_login_at = unixepoch(), updated_at = unixepoch() WHERE id = ?', [user.id]);

    const token = generateToken(user.id);
    res.json({ token, user: formatUser(user) });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ — دوبارە هەوڵ بدە.' });
  }
});

// POST /api/auth/guest
router.post('/guest', async (req, res) => {
  try {
    const { displayName } = req.body;
    const id = generateId();
    const countRow = get('SELECT COUNT(*) as c FROM users');
    const guestNum = (countRow?.c || 0) + 1;
    const username = `guest_${guestNum}`;
    const name = sanitizeText(displayName || `یاریزان ${guestNum}`, 30);

    run('INSERT INTO users (id, username, display_name) VALUES (?, ?, ?)', [id, username, name]);

    const token = generateToken(id);
    const user = get('SELECT * FROM users WHERE id = ?', [id]);
    res.status(201).json({ token, user: formatUser(user) });
  } catch (err) {
    console.error('Guest error:', err);
    res.status(500).json({ error: 'هەڵەی ناوخۆ — دوبارە هەوڵ بدە.' });
  }
});

// POST /api/auth/refresh
router.post('/refresh', async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'توکن پێویستە.' });

    const decoded = verifyToken(token);
    const newToken = generateToken(decoded.userId);
    const user = get('SELECT * FROM users WHERE id = ?', [decoded.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    res.json({ token: newToken, user: formatUser(user) });
  } catch (err) {
    return res.status(401).json({ error: 'توکن نادروستە.' });
  }
});

// GET /api/auth/me
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = get('SELECT * FROM users WHERE id = ?', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });
    res.json({ user: formatUser(user) });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

function formatUser(u) {
  if (!u) return null;
  return {
    id: u.id,
    username: u.username,
    displayName: u.display_name,
    coins: u.coins,
    gems: u.gems,
    xp: u.xp,
    level: u.level,
    wins: u.wins,
    gamesPlayed: u.games_played,
    streak: u.streak,
    createdAt: u.created_at,
  };
}

module.exports = router;
module.exports.formatUser = formatUser;
