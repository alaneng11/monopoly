/**
 * Shop & Cosmetics Routes — مۆنۆپۆلی هەولێر
 * 
 * Handles cosmetic items catalog, user inventory, purchase, and equipping items.
 */

const express = require('express');
const { query, queryOne, run } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── Catalog ──────────────────────────────────────────────────

router.get('/catalog', async (req, res) => {
  try {
    const items = await query('SELECT * FROM cosmetics WHERE is_for_sale = 1 ORDER BY sort_order ASC, coin_price ASC');
    res.json({
      items: items.map(i => ({
        id: i.id,
        name: i.name,
        description: i.description,
        category: i.category,
        rarity: i.rarity,
        coinPrice: i.coin_price,
        gemPrice: i.gem_price,
        icon: i.icon,
        previewAsset: i.preview_asset,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── User Inventory ───────────────────────────────────────────

router.get('/inventory', authMiddleware, async (req, res) => {
  try {
    const userItems = await query(
      'SELECT uc.*, c.name, c.description, c.category, c.rarity, c.icon, c.preview_asset FROM user_cosmetics uc JOIN cosmetics c ON c.id = uc.cosmetic_id WHERE uc.user_id = $1 ORDER BY uc.acquired_at DESC',
      [req.userId]
    );

    res.json({
      inventory: userItems.map(i => ({
        cosmeticId: i.cosmetic_id,
        name: i.name,
        description: i.description,
        category: i.category,
        rarity: i.rarity,
        icon: i.icon,
        previewAsset: i.preview_asset,
        isEquipped: !!i.is_equipped,
        acquiredAt: i.acquired_at,
      })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Buy Cosmetic ─────────────────────────────────────────────

router.post('/buy', authMiddleware, async (req, res) => {
  try {
    const { cosmeticId, currency = 'coins' } = req.body;
    const item = await queryOne('SELECT * FROM cosmetics WHERE id = $1', [cosmeticId]);
    if (!item) return res.status(404).json({ error: 'کاڵا نەدۆزرایەوە.' });

    const user = await queryOne('SELECT coins, gems FROM users WHERE id = $1', [req.userId]);
    if (!user) return res.status(404).json({ error: 'یاریزان نەدۆزرایەوە.' });

    const existing = await queryOne('SELECT 1 FROM user_cosmetics WHERE user_id = $1 AND cosmetic_id = $2', [req.userId, cosmeticId]);
    if (existing) return res.status(400).json({ error: 'پێشتر ئەم کاڵایەت کڕیوە.' });

    const now = Math.floor(Date.now() / 1000);

    if (currency === 'gems') {
      if (user.gems < item.gem_price) return res.status(400).json({ error: 'گەوهەرت بەس نییە.' });
      await run('UPDATE users SET gems = gems - $1, updated_at = $2 WHERE id = $3', [item.gem_price, now, req.userId]);
    } else {
      if (user.coins < item.coin_price) return res.status(400).json({ error: 'دراوت بەس نییە.' });
      await run('UPDATE users SET coins = coins - $1, updated_at = $2 WHERE id = $3', [item.coin_price, now, req.userId]);
    }

    await run('INSERT INTO user_cosmetics (user_id, cosmetic_id, is_equipped, acquired_at) VALUES ($1,$2,0,$3)', [req.userId, cosmeticId, now]);

    const updatedUser = await queryOne('SELECT coins, gems FROM users WHERE id = $1', [req.userId]);
    res.json({
      success: true,
      cosmeticId,
      coins: updatedUser.coins,
      gems: updatedUser.gems,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Equip Cosmetic ───────────────────────────────────────────

router.post('/equip', authMiddleware, async (req, res) => {
  try {
    const { cosmeticId } = req.body;
    const item = await queryOne('SELECT * FROM cosmetics WHERE id = $1', [cosmeticId]);
    if (!item) return res.status(404).json({ error: 'کاڵا نەدۆزرایەوە.' });

    const owned = await queryOne('SELECT 1 FROM user_cosmetics WHERE user_id = $1 AND cosmetic_id = $2', [req.userId, cosmeticId]);
    if (!owned) return res.status(400).json({ error: 'خاوەنی ئەم کاڵایە نیت.' });

    // Unequip all items in the same category
    const sameCat = await query('SELECT id FROM cosmetics WHERE category = $1', [item.category]);
    for (const c of sameCat) {
      await run('UPDATE user_cosmetics SET is_equipped = 0 WHERE user_id = $1 AND cosmetic_id = $2', [req.userId, c.id]);
    }

    // Equip selected
    await run('UPDATE user_cosmetics SET is_equipped = 1 WHERE user_id = $1 AND cosmetic_id = $2', [req.userId, cosmeticId]);

    res.json({ equipped: true, cosmeticId, category: item.category });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
