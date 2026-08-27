/**
 * JWT Authentication Middleware — مۆنۆپۆلی هەولێر
 */

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'hawler-monopoly-dev-secret-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

function generateToken(userId) {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

/**
 * Express middleware — attaches req.userId from Authorization header.
 */
function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'تۆمار نەبووە — پێویستە بچۆرە ژوورەوە.', code: 'NOT_AUTH' });
  }
  try {
    const token = header.slice(7);
    const decoded = verifyToken(token);
    req.userId = decoded.userId;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'توکن نادروستە یان بەسەرچووە.', code: 'TOKEN_EXPIRED' });
  }
}

/**
 * Optional auth — sets req.userId if token present, but doesn't block.
 */
function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    try {
      const decoded = verifyToken(header.slice(7));
      req.userId = decoded.userId;
    } catch (_) {}
  }
  next();
}

module.exports = { generateToken, verifyToken, authMiddleware, optionalAuth, JWT_SECRET };
