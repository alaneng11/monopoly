# مۆنۆپۆلی هەولێر — Hawler Monopoly
### Full Commercial Multiplayer Kurdish Board Game & SaaS Platform

🏰 A complete, commercial-quality Kurdish online multiplayer board game themed around Hawler (Erbil) and Kurdish culture.

**Kurdish Sorani** UI • RTL layout • Pass & Play • 6 AI Personalities • Real-Time Online Multiplayer • Live Auctions • P2P Trading • Banking & Mortgages • Seasons & Battle Pass • Cosmetics Shop • Match History • Spectator Mode • PostgreSQL 16 on Railway

---

## 🌟 Key Features

- 🎲 **Server-Authoritative Game Engine** — Authoritative dice rolls, step-by-step token animations on 40 Hawler landmarks, doubles mechanics, 30s turn timeout scheduler.
- 🏰 **40 Hawler Landmarks & Properties** — Citadel, Minaret of Choli, Sami Abdulrahman Park, Majidi Mall, Dream City, Empire World, Korek Mountain.
- 🔨 **Live Auction System** — Real-time bidding with a 20-second timer, automatic timer extensions on outbids, and instant property deed assignment.
- 🤝 **Player-to-Player Trading** — Atomic multi-asset trade proposals (cash, properties) with dual-acceptance validation.
- 🏦 **Mortgage & Banking** — Mortgage properties for 50% cash and unmortgage with standard 10% interest.
- 🤖 **Strategic AI** — 6 distinct AI personalities (Balanced, Investor, Aggressive, Conservative, Risk Taker, Opportunist) across 4 difficulty levels.
- 🏆 **Seasons & Battle Pass** — 30 tiers of progression with XP, exclusive cosmetics, coins, and gems.
- 🎁 **Daily Rewards & Missions** — 7-day login streaks and dynamic daily/weekly missions.
- 🛍️ **Cosmetics Shop** — Dice skins (Gold, Citadel, Neon, Emerald), Avatar frames, and Board themes.
- 📜 **Match History & Deep Stats** — Completed matches saved to PostgreSQL with full player breakdown.
- 💬 **Real-Time Chat & Quick Reactions** — In-game chat, floating emojis (`🔥`, `❤️`, `😂`, `👍`), and private friend messaging.
- 👁️ **Spectator Mode** — Watch live games in real time.
- 🔊 **Sound & Haptics** — Web AudioContext synthesized sound effects and device haptic vibrations.

---

## 🚀 Quick Start

### 1. Flutter Web / Mobile Client
```bash
cd hawler_monopoly
flutter pub get
flutter run -d chrome --web-port=5000
```

### 2. Backend Server (Local / Railway)
```bash
cd backend
npm install
npm run dev
```

### 3. Automated Verification Tests
```bash
# Run 30-Scenario Full QA & Multiplayer Stress Suite
node scratch/qa_full_suite.js

# Run Migration DDL Verification
node backend/src/migrate.js

# Run Flutter Analyzer
cd hawler_monopoly
flutter analyze --no-pub
```

---

## 📚 Complete Technical Documentation

- **[PRODUCTION_INFRASTRUCTURE.md](PRODUCTION_INFRASTRUCTURE.md)** — Production Architecture, Services, Storage, Schedulers & Scaling
- **[RAILWAY_SETUP.md](RAILWAY_SETUP.md)** — Step-by-Step Railway PostgreSQL Linking & Deployment Guide
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** — Database Migration System, DDL Scripts & CLI
- **[DISASTER_RECOVERY.md](DISASTER_RECOVERY.md)** — Backups, Snapshots, Restores & Incident Playbooks
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Full Frontend & Backend System Architecture
- **[DATABASE.md](DATABASE.md)** — 26 Relational Tables, Constraints, Indices & Schema Reference
- **[API.md](API.md)** — REST API & WebSocket Protocol Documentation
- **[DEPLOYMENT.md](DEPLOYMENT.md)** — Environment Variables, Local Setup & CI/CD
- **[FEATURE_STATUS.md](FEATURE_STATUS.md)** — 45-Phase Master Audit & Verification Matrix

