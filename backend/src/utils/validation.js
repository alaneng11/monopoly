/**
 * Validation & Security Utilities — مۆنۆپۆلی هەولێر
 * 
 * Server-side validation for all critical game operations.
 * Never trust the client for money, dice, ownership, or rewards.
 */

const { v4: uuidv4 } = require('uuid');

/**
 * Validate dice result is within legal range.
 */
function validateDice(d1, d2) {
  return Number.isInteger(d1) && Number.isInteger(d2) && d1 >= 1 && d1 <= 6 && d2 >= 1 && d2 <= 6;
}

/**
 * Validate player has sufficient funds.
 */
function validateFunds(player, amount) {
  return player && player.cash >= amount && amount >= 0;
}

/**
 * Validate player owns a tile.
 */
function validateOwnership(tiles, tileIndex, userId) {
  const tile = tiles[tileIndex];
  return tile && tile.ownerId === userId;
}

/**
 * Validate auction bid.
 */
function validateBid(auction, userId, amount) {
  if (!auction) return false;
  if (amount <= auction.highestBid) return false;
  if (amount > auction.basePrice) return false;
  if (auction.passedBidders.includes(userId)) return false;
  return true;
}

/**
 * Validate trade offer.
 */
function validateTrade(state, offer) {
  if (!offer || !offer.fromPlayerId || !offer.toPlayerId) return false;
  if (offer.fromPlayerId === offer.toPlayerId) return false;
  const from = state.players.find(p => p.id === offer.fromPlayerId);
  const to = state.players.find(p => p.id === offer.toPlayerId);
  if (!from || !to) return false;
  if (from.bankrupt || to.bankrupt) return false;
  if (offer.moneyFrom > 0 && from.cash < offer.moneyFrom) return false;
  if (offer.moneyTo > 0 && to.cash < offer.moneyTo) return false;
  for (const idx of (offer.tilesFrom || [])) {
    if (!state.tiles[idx] || state.tiles[idx].ownerId !== offer.fromPlayerId) return false;
  }
  for (const idx of (offer.tilesTo || [])) {
    if (!state.tiles[idx] || state.tiles[idx].ownerId !== offer.toPlayerId) return false;
  }
  return true;
}

/**
 * Generate a unique ID.
 */
function generateId() {
  return uuidv4();
}

/**
 * Generate a room code.
 */
function generateRoomCode(length = 5) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < length; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

/**
 * Sanitize text input — remove HTML, limit length.
 */
function sanitizeText(text, maxLength = 500) {
  if (!text || typeof text !== 'string') return '';
  return text
    .replace(/<[^>]*>/g, '')
    .trim()
    .slice(0, maxLength);
}

/**
 * Rate limiter helper — simple in-memory token bucket.
 */
const rateLimitBuckets = new Map();

function rateLimit(key, maxRequests = 30, windowMs = 60000) {
  const now = Date.now();
  const bucket = rateLimitBuckets.get(key);
  if (!bucket || now - bucket.start > windowMs) {
    rateLimitBuckets.set(key, { start: now, count: 1 });
    return true;
  }
  bucket.count++;
  return bucket.count <= maxRequests;
}

module.exports = {
  validateDice,
  validateFunds,
  validateOwnership,
  validateBid,
  validateTrade,
  generateId,
  generateRoomCode,
  sanitizeText,
  rateLimit,
};
