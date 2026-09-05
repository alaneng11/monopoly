# FEATURE_STATUS.md — مۆنۆپۆلی هەولێر (Feature Audit Matrix)

Status of each subsystem against **verified** behaviour — every `COMPLETE` below
is backed by an assertion in `scratch/qa_full_suite.js` (backend) or
`hawler_monopoly/test/widget_test.dart` (client engine), or by manually playing
the flow in a browser.

Allowed statuses: `COMPLETE` | `PARTIAL` | `NOT STARTED`

> **How to reproduce:** start the backend (`cd backend && npm run dev`), then
> `node scratch/qa_full_suite.js`. It plays a full online game to bankruptcy and
> asserts the outcome. A non-zero exit code means something regressed.

## Core game

| # | Subsystem | Status | Verified by |
|---|---|---|---|
| 1 | Authentication & guest mode | **COMPLETE** | QA: guest ×3, unique tokens, invalid-JWT rejection |
| 2 | Offline fallback (play with no server) | **COMPLETE** | Guest login falls through to local profile |
| 3 | Rooms, lobby & public room browser | **COMPLETE** | QA: create → appears in `/api/rooms/public` |
| 4 | Multiplayer synchronisation | **COMPLETE** | QA: 3 players visible in one room |
| 5 | Local Pass & Play | **COMPLETE** | Played in browser; 16 engine unit tests |
| 6 | Strategic AI (6 personalities) | **PARTIAL** | Works in Pass & Play only — **no AI in online rooms** |
| 7 | Server-authoritative dice | **COMPLETE** | QA: dice in 1–6, server-issued |
| 8 | Tile-by-tile board movement | **COMPLETE** | QA: position == (start + total) % 40 |
| 9 | Turn system & 30s auto-advance | **COMPLETE** | Scheduler covers every stallable phase |
| 10 | Properties & house upgrades | **COMPLETE** | QA: purchase deducts exact price, deed recorded |
| 11 | Rent calculation & economy | **COMPLETE** | QA + engine tests |
| 12 | Mortgage & banking | **COMPLETE** | QA: mortgage raises cash, unmortgage costs more |
| 13 | Live auctions | **COMPLETE** | QA: declining a property opens an auction |
| 14 | P2P multi-asset trading | **COMPLETE** | Engine tests (valid + illegal trade) |
| 15 | Chance & Chest card events | **COMPLETE** | Server draws *and applies*; chained moves resolve |
| 16 | Bankruptcy & game completion | **COMPLETE** | QA: game reaches gameOver, one solvent player |
| 17 | Match history & winner rewards | **COMPLETE** | QA: match row written, room closed |

## Social & meta

| # | Subsystem | Status | Verified by |
|---|---|---|---|
| 18 | In-game chat & reactions | **COMPLETE** | QA: message persists, readable by another player |
| 19 | Friends & requests | **COMPLETE** | QA: request → accept → friendship |
| 20 | Daily rewards & streaks | **COMPLETE** | QA: claim succeeds, duplicate rejected |
| 21 | Cosmetics shop & inventory | **COMPLETE** | QA: buy → equip → appears in inventory |
| 22 | Leaderboards | **COMPLETE** | QA: ranked leaders returned |
| 23 | Profile & customisation | **COMPLETE** | QA: authenticated `/api/users/me` |
| 24 | Seasons & battle pass | **PARTIAL** | Endpoints seeded and respond; progression not asserted end-to-end |
| 25 | Spectator mode | **PARTIAL** | Join succeeds and returns state; live sync not asserted |
| 26 | Session reconnect recovery | **PARTIAL** | WebSocket auth verified; full reconnect path not asserted |
| 27 | Host migration on disconnect | **PARTIAL** | Implemented, not covered by an assertion |

## Platform & infrastructure

| # | Subsystem | Status | Notes |
|---|---|---|---|
| 28 | PostgreSQL (Railway) | **COMPLETE** | Auto-migrates and seeds on boot |
| 29 | SQLite (local dev) | **COMPLETE** | Dialect-safe SQL; full game loop verified locally |
| 30 | Audio & haptics | **COMPLETE** | Real Web Audio interop; unlocked on first tap |
| 31 | Anti-cheat validation | **COMPLETE** | QA: out-of-turn roll and invalid JWT rejected |
| 32 | Flutter Web | **COMPLETE** | `flutter build web --release` |
| 33 | Windows desktop | **PARTIAL** | Project scaffolding present, not release-tested |
| 34 | Android / iOS | **NOT STARTED** | No `android/` or `ios/` directory — web is the shipping target |
| 35 | Custom fonts & artwork | **NOT STARTED** | `assets/` is empty; fonts come from Google Fonts at runtime |

## Known gaps

- **No AI opponents online.** An online demo needs two real clients.
- **No bundled fonts.** Kurdish text is fetched from Google Fonts at runtime, so
  a fully offline first load shows a brief tofu flash.
- **No artwork.** `assets/images`, `assets/icons` and `assets/lottie` hold only
  `.gitkeep`; player tokens use Material icons.
- **SQLite is a single-process, in-memory database** snapshotted to disk every
  30s. Fine for local development, not for multi-instance deployment — use
  PostgreSQL (`DATABASE_URL`) for anything shared.
