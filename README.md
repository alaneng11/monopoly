# مۆنۆپۆلی هەولێر — Hawler Monopoly

🏰 A premium mobile board game themed around Hawler (Erbil) and Kurdish culture.

**Kurdish Sorani** UI • RTL layout • Pass & Play • AI • Online Multiplayer

## Features

- 🎲 **Dice & Movement** — Animated dual dice with energy system and multipliers (×1–×20)
- 🏠 **Properties** — 40 Kurdish-named tiles with rent, upgrades, mortgage, trading
- 🤖 **AI** — 6 personalities × 4 difficulty levels
- 💰 **Economy** — Full money system with transactions, rent, taxes, auctions
- 🎯 **Challenges** — Daily & weekly challenges with real rewards
- 🏆 **Achievements** — Unlock achievements from actual gameplay
- 📊 **Leaderboards** — Weekly, monthly, and all-time rankings
- 💬 **Chat** — In-game and friend-to-friend real-time chat with emoji
- 👥 **Friends** — Friend list, requests, and direct messaging
- 🎴 **Cards** — Chance & event cards with Hawler-themed effects
- 🎪 **Events** — Dynamic events: tourism boom, festivals, market crashes
- 📱 **Cross-platform** — Android, iOS, Web, Desktop

## Quick Start

### Flutter App
```bash
cd hawler_monopoly
flutter pub get
flutter run
```

### Backend Server
```bash
cd backend
npm install
cp .env.example .env  # Edit JWT_SECRET and other values
npm start
```

Backend runs at `http://localhost:3000` with health check at `/health`.

## Architecture

```
hawler_monopoly/    → Flutter client (Riverpod + GoRouter)
backend/            → Node.js server (Express + SQLite + WebSocket)
docs/               → Documentation
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture.

## Environment Variables

### Backend
| Variable | Default | Description |
|----------|---------|-------------|
| PORT | 3000 | Server port |
| DB_PATH | ./data.db | SQLite database path |
| JWT_SECRET | (required) | Secret for JWT tokens |
| JWT_EXPIRES_IN | 7d | Token expiry |

### Flutter
| Variable | Default | Description |
|----------|---------|-------------|
| API_BASE_URL | http://localhost:3000 | Backend URL |

## Deployment

### Railway (Backend)
1. Push to GitHub
2. Connect repo in Railway
3. Add SQLite volume or configure `DB_PATH`
4. Set environment variables (especially `JWT_SECRET`)
5. Railway auto-deploys via Dockerfile

### Flutter Web
```bash
cd hawler_monopoly
flutter build web
# Serve build/web/ directory
```

## Tech Stack

- **Frontend**: Flutter 3.3+, Dart, Riverpod, GoRouter
- **Backend**: Node.js 18+, Express, SQLite (better-sqlite3), WebSocket (ws)
- **Auth**: JWT (jsonwebtoken), bcryptjs
- **Database**: SQLite with WAL mode
- **Deployment**: Docker, Railway

## License

Proprietary — All rights reserved.
