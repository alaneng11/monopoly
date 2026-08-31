/**
 * Rewards & Progression Routes — مۆنۆپۆلی هەولێر
 * 
 * Handles Daily Login Rewards, Daily/Weekly Missions, and Season Battle Pass.
 */

const express = require('express');
const { query, queryOne, run } = require('../models/database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── Daily Login Rewards ──────────────────────────────────────

router.get('/daily', authMiddleware, async (req, res) => {
  try {
    const user = await queryOne('SELECT streak, last_login_at FROM users WHERE id = $1', [req.userId]);
    const rewards = await query('SELECT * FROM daily_rewards ORDER BY day_number ASC');
    const claimed = await query('SELECT day_number, claimed_at FROM user_daily_rewards WHERE user_id = $1', [req.userId]);
    const claimedDays = claimed.map(c => c.day_number);

    res.json({
      streak: user?.streak || 1,
      rewards: rewards.map(r => ({
        dayNumber: r.day_number,
        coinReward: r.coin_reward,
        gemReward: r.gem_reward,
        diceReward: r.dice_reward,
        xpReward: r.xp_reward,
        description: r.description,
        isClaimed: claimedDays.includes(r.day_number),
      })),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/daily/claim', authMiddleware, async (req, res) => {
  try {
    const { dayNumber } = req.body;
    if (!dayNumber) return res.status(400).json({ error: 'ڕۆژی خەڵات دیاری بکە.' });

    const reward = await queryOne('SELECT * FROM daily_rewards WHERE day_number = $1', [dayNumber]);
    if (!reward) return res.status(404).json({ error: 'خەڵات نەدۆزرایەوە.' });

    const alreadyClaimed = await queryOne('SELECT 1 FROM user_daily_rewards WHERE user_id = $1 AND day_number = $2', [req.userId, dayNumber]);
    if (alreadyClaimed) return res.status(400).json({ error: 'ئەم خەڵاتە پێشتر وەرگیراوە.' });

    const now = Math.floor(Date.now() / 1000);
    await run('INSERT INTO user_daily_rewards (user_id, day_number, claimed_at) VALUES ($1,$2,$3)', [req.userId, dayNumber, now]);

    // Credit rewards to user
    await run(
      'UPDATE users SET coins = coins + $1, gems = gems + $2, xp = xp + $3, streak = streak + 1, updated_at = $4 WHERE id = $5',
      [reward.coin_reward, reward.gem_reward, reward.xp_reward, now, req.userId]
    );

    const user = await queryOne('SELECT coins, gems, xp, streak FROM users WHERE id = $1', [req.userId]);
    res.json({
      claimed: true,
      coins: user.coins,
      gems: user.gems,
      xp: user.xp,
      streak: user.streak,
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Missions / Challenges ────────────────────────────────────

router.get('/missions', authMiddleware, async (req, res) => {
  try {
    const missions = await query('SELECT * FROM missions ORDER BY sort_order ASC, period ASC');
    const userMissions = await query('SELECT * FROM user_missions WHERE user_id = $1', [req.userId]);
    const uMap = {};
    for (const um of userMissions) {
      uMap[um.mission_id] = um;
    }

    res.json({
      missions: missions.map(m => {
        const um = uMap[m.id];
        return {
          id: m.id,
          title: m.title,
          description: m.description,
          period: m.period,
          target: m.target,
          actionType: m.action_type,
          xpReward: m.xp_reward,
          coinReward: m.coin_reward,
          diceReward: m.dice_reward,
          progress: um?.progress || 0,
          isCompleted: (um?.progress || 0) >= m.target || !!um?.completed,
          isClaimed: !!um?.claimed,
        };
      }),
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/missions/:id/claim', authMiddleware, async (req, res) => {
  try {
    const missionId = req.params.id;
    const mission = await queryOne('SELECT * FROM missions WHERE id = $1', [missionId]);
    if (!mission) return res.status(404).json({ error: 'ئەرک نەدۆزرایەوە.' });

    const now = Math.floor(Date.now() / 1000);
    const startPeriod = now - (now % 86400); // Today start

    const um = await queryOne('SELECT * FROM user_missions WHERE user_id = $1 AND mission_id = $2', [req.userId, missionId]);
    if (um && um.claimed) return res.status(400).json({ error: 'ئەم ئەرکە پێشتر وەرگیراوە.' });

    await run(
      'INSERT INTO user_missions (user_id, mission_id, progress, completed, claimed, period_start, completed_at) VALUES ($1,$2,$3,1,1,$4,$5) ON CONFLICT (user_id, mission_id, period_start) DO UPDATE SET claimed = 1, completed = 1',
      [req.userId, missionId, mission.target, startPeriod, now]
    );

    // Credit rewards
    await run(
      'UPDATE users SET coins = coins + $1, xp = xp + $2, updated_at = $3 WHERE id = $4',
      [mission.coin_reward, mission.xp_reward, now, req.userId]
    );

    const user = await queryOne('SELECT coins, xp FROM users WHERE id = $1', [req.userId]);
    res.json({ claimed: true, coins: user.coins, xp: user.xp });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

// ── Season Pass ──────────────────────────────────────────────

router.get('/season', authMiddleware, async (req, res) => {
  try {
    const season = await queryOne('SELECT * FROM seasons WHERE is_active = 1 LIMIT 1');
    if (!season) return res.status(404).json({ error: 'هیچ وەرزێکی چالاک نییە.' });

    const userSeason = await queryOne('SELECT * FROM user_seasons WHERE user_id = $1 AND season_id = $2', [req.userId, season.id]);
    const claimed = userSeason?.claimed_tiers ? (typeof userSeason.claimed_tiers === 'string' ? JSON.parse(userSeason.claimed_tiers) : userSeason.claimed_tiers) : [];

    res.json({
      season: {
        id: season.id,
        name: season.name,
        description: season.description,
        startDate: season.start_date,
        endDate: season.end_date,
        maxTier: season.max_tier,
      },
      userProgression: {
        currentTier: userSeason?.current_tier || 1,
        seasonXp: userSeason?.season_xp || 0,
        claimedTiers: claimed,
      },
    });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

router.post('/season/claim', authMiddleware, async (req, res) => {
  try {
    const { tier } = req.body;
    const season = await queryOne('SELECT * FROM seasons WHERE is_active = 1 LIMIT 1');
    if (!season) return res.status(404).json({ error: 'هیچ وەرزێکی چالاک نییە.' });

    const now = Math.floor(Date.now() / 1000);
    const userSeason = await queryOne('SELECT * FROM user_seasons WHERE user_id = $1 AND season_id = $2', [req.userId, season.id]);
    let claimed = userSeason?.claimed_tiers ? (typeof userSeason.claimed_tiers === 'string' ? JSON.parse(userSeason.claimed_tiers) : userSeason.claimed_tiers) : [];

    if (claimed.includes(tier)) return res.status(400).json({ error: 'ئەم پلەیە پێشتر وەرگیراوە.' });
    claimed.push(tier);

    await run(
      'INSERT INTO user_seasons (user_id, season_id, current_tier, season_xp, claimed_tiers, updated_at) VALUES ($1,$2,$3,0,$4,$5) ON CONFLICT (user_id, season_id) DO UPDATE SET claimed_tiers = $4, updated_at = $5',
      [req.userId, season.id, tier, JSON.stringify(claimed), now]
    );

    // Award tier bonus
    const rewardCoins = tier * 100;
    await run('UPDATE users SET coins = coins + $1, updated_at = $2 WHERE id = $3', [rewardCoins, now, req.userId]);

    res.json({ claimed: true, tier, coinsAwarded: rewardCoins, claimedTiers: claimed });
  } catch (err) {
    res.status(500).json({ error: 'هەڵەی ناوخۆ.' });
  }
});

module.exports = router;
