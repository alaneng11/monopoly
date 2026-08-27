# مۆنۆپۆلی هەولێر — Architecture

## Project Structure

```
/
├── hawler_monopoly/         # Flutter mobile/web client
│   ├── lib/
│   │   ├── core/            # Theme, widgets, common UI
│   │   ├── data/            # Persistence, Firebase, API client
│   │   ├── domain/          # Game engine, models, AI
│   │   ├── features/        # UI screens and widgets
│   │   └── presentation/    # State management (Riverpod)
│   └── pubspec.yaml
│
├── backend/                 # Node.js production backend
│   ├── src/
│   │   ├── index.js         # Server entry (Express + WebSocket)
│   │   ├── middleware/       # JWT auth
│   │   ├── models/          # SQLite database schemas
│   │   ├── routes/          # REST API endpoints
│   │   ├── services/        # Business logic
│   │   └── utils/           # Validation, security
│   ├── Dockerfile           # Railway deployment
│   ├── railway.json         # Railway config
│   └── package.json
│
├── docs/                    # Documentation
└── .github/                 # CI/CD (optional)
```

## Game Engine (Local)

The Flutter app includes a **complete local game engine** in `domain/game_engine.dart`:

- Pure Dart, no server dependency
- Handles dice, movement, properties, rent, trading, auctions, cards, events
- AI with 6 personalities and 4 difficulty levels
- Used for offline/Pass & Play mode

## Backend (Online)

The Node.js backend provides **server-authoritative** game operations:

### Authentication
- JWT-based auth with refresh tokens
- Guest login for quick play
- Username/password registration

### Game Rooms
- Create/join/leave rooms
- Public and private rooms
- Room codes for easy joining
- Real-time player sync via WebSocket

### Server-Authoritative Game Actions
- **Dice**: Server generates random results (never trust client)
- **Movement**: Server validates and applies movement
- **Properties**: Server validates ownership and transactions
- **Rent**: Server calculates and applies rent
- **Trading**: Server validates both sides before execution
- **Auctions**: Server manages bidding and closes auctions
- **Economy**: All money flows through server-side ledger

### Real-time Communication
- WebSocket for live game state sync
- In-game chat (text + emoji)
- Friend chat (one-to-one)
- Player presence indicators

### Database (SQLite)
- Users and profiles
- Game rooms and states
- Match history
- Leaderboards
- Chat messages
- Friend relationships
- Achievements
- Challenges
- Transaction ledger (economy audit)

## Security Model

### Client-Side (Flutter)
- Local game engine for offline play
- API client for server communication
- No secret logic — all important validation is server-side

### Server-Side (Node.js)
- **Never trust client for**: dice results, money, ownership, rewards, XP, leaderboard
- JWT authentication on all sensitive endpoints
- Input validation and sanitization
- Rate limiting on chat and actions
- Transaction ledger for economy audit

## Deployment

### Flutter → Web/Mobile
```bash
cd hawler_monopoly
flutter build web      # Web
flutter build apk      # Android
flutter build ios      # iOS
```

### Backend → Railway
```bash
cd backend
# Configure .env with JWT_SECRET and other variables
# Push to GitHub, Railway auto-deploys via Dockerfile
```

## Environment Variables

### Backend (.env)
- `PORT` — Server port (default: 3000)
- `DB_PATH` — SQLite database path
- `JWT_SECRET` — Secret key for JWT tokens
- `JWT_EXPIRES_IN` — Token expiry (default: 7d)

### Flutter (.env)
- `API_BASE_URL` — Backend API URL
