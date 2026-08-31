# API & WEBSOCKET SPECIFICATION — مۆنۆپۆلی هەولێر (Monopoly Hawler)

Complete reference for all REST endpoints and WebSocket real-time event messages.

---

## 1. Base URLs & Protocol Endpoints

- **Production REST Base URL**: `https://backend-production-bdeaa.up.railway.app`
- **Production WebSocket URL**: `wss://backend-production-bdeaa.up.railway.app/ws`
- **Local Dev REST Base URL**: `http://localhost:3000`
- **Local Dev WebSocket URL**: `ws://localhost:3000/ws`
- **Health Check**: `GET /health`
- **Web Dashboard**: `GET /`

---

## 2. Authentication Headers & Response Conventions

- All authenticated endpoints require the `Authorization` header:
  ```http
  Authorization: Bearer <jwt_token>
  ```
- **Error Response Format**:
  ```json
  { "error": "پەیامی هەڵە بە زمانی کوردی" }
  ```

---

## 3. REST API Endpoints

### A. Authentication (`/api/auth`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `POST` | `/api/auth/register` | No | Register new user `{ username, password, displayName }` |
| `POST` | `/api/auth/login` | No | Login with username and password `{ username, password }` |
| `POST` | `/api/auth/guest` | No | Instant Kurdish guest account creation `{ displayName? }` |
| `POST` | `/api/auth/refresh` | No | Refresh expired JWT token `{ token }` |
| `GET` | `/api/auth/me` | **Yes** | Returns authenticated user profile, statistics, and settings |

### B. User Profiles & Avatars (`/api/users`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `GET` | `/api/users/:id` | No | Get public user profile and unlocked achievements |
| `PUT` | `/api/users/me` | **Yes** | Update display name and avatar URL `{ displayName?, avatarUrl? }` |
| `GET` | `/api/users/me/stats` | **Yes** | Get detailed gameplay stats (wins, net worth, properties) |
| `POST` | `/api/users/me/avatar` | **Yes** | Upload profile picture `{ imageBase64, mimeType }` |
| `POST` | `/api/users/me/achievements` | **Yes** | Claim achievement reward `{ achievementId }` |

### C. Game Rooms & Multiplayer Engine (`/api/rooms`, `/api/games`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `POST` | `/api/rooms` | **Yes** | Create room `{ roomName?, isPublic?, maxPlayers?, startCash? }` |
| `GET` | `/api/rooms/public` | No | List active public lobbies waiting for players |
| `GET` | `/api/rooms/:code` | **Yes** | Get room details and joined players |
| `POST` | `/api/rooms/:code/join` | **Yes** | Join room by 5-letter code |
| `POST` | `/api/rooms/:code/ready` | **Yes** | Toggle ready status in lobby `{ ready: boolean }` |
| `POST` | `/api/rooms/:code/start` | **Yes** | Host starts game (initializes `game_states`) |
| `POST` | `/api/rooms/:code/leave` | **Yes** | Leave room / forfeit active game |
| `POST` | `/api/games/:code/roll` | **Yes** | Authoritative dice roll (validates turn and energy) |
| `POST` | `/api/games/:code/move` | **Yes** | Step movement execution |
| `POST` | `/api/games/:code/resolve` | **Yes** | Landing tile action resolution (salary, tax, jail) |
| `POST` | `/api/games/:code/buy` | **Yes** | Buy unowned property |
| `POST` | `/api/games/:code/upgrade` | **Yes** | Upgrade property house/hotel `{ tileIndex }` |
| `POST` | `/api/games/:code/mortgage` | **Yes** | Mortgage property for 50% cash `{ tileIndex }` |
| `POST` | `/api/games/:code/unmortgage` | **Yes** | Unmortgage property for 50% + 10% fee `{ tileIndex }` |
| `POST` | `/api/games/:code/end-turn` | **Yes** | End active player turn |
| `POST` | `/api/games/:code/auction/bid` | **Yes** | Place bid in active auction `{ amount }` |
| `POST` | `/api/games/:code/auction/pass` | **Yes** | Pass active auction bid |
| `POST` | `/api/games/:code/trade/propose` | **Yes** | Propose P2P trade `{ toPlayerId, fromMoney, toMoney, fromTileIndices, toTileIndices }` |
| `POST` | `/api/games/:code/trade/respond` | **Yes** | Respond to trade offer `{ accept: boolean }` |
| `POST` | `/api/games/:code/spectate` | **Yes** | Watch live match as spectator |
| `GET` | `/api/games/:code/state` | **Yes** | Fetch current full authoritative game state |
| `GET` | `/api/games/:code/transactions` | **Yes** | Fetch financial audit log for match |

### D. Rewards, Missions & Seasons (`/api/rewards`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `GET` | `/api/rewards/daily` | **Yes** | 7-day daily login streak calendar & claim status |
| `POST` | `/api/rewards/daily/claim` | **Yes** | Claim daily reward `{ dayNumber }` |
| `GET` | `/api/rewards/missions` | **Yes** | List daily and weekly missions with player progress |
| `POST` | `/api/rewards/missions/:id/claim` | **Yes** | Claim completed mission rewards |
| `GET` | `/api/rewards/season` | **Yes** | Active Battle Pass season info and tier rewards |
| `POST` | `/api/rewards/season/claim` | **Yes** | Claim unlocked season tier reward `{ tier }` |

### E. Cosmetics & Shop (`/api/shop`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `GET` | `/api/shop/catalog` | No | List items for sale (dice, frames, board themes) |
| `GET` | `/api/shop/inventory` | **Yes** | List user's purchased cosmetics |
| `POST` | `/api/shop/buy` | **Yes** | Buy cosmetic with Coins or Gems `{ cosmeticId, currency }` |
| `POST` | `/api/shop/equip` | **Yes** | Equip cosmetic to active profile `{ cosmeticId }` |

### F. Social, Chat & Match History (`/api/friends`, `/api/chat`, `/api/matches`, `/api/leaderboard`)
| Method | Path | Auth Required | Description |
|---|---|---|---|
| `GET` | `/api/friends` | **Yes** | List friends and pending requests |
| `POST` | `/api/friends/add/:id` | **Yes** | Send friend request |
| `POST` | `/api/friends/accept/:id` | **Yes** | Accept friend request |
| `POST` | `/api/friends/remove/:id` | **Yes** | Remove friend |
| `POST` | `/api/chat/friend/:id` | **Yes** | Send 1-on-1 private message |
| `GET` | `/api/chat/friend/:id` | **Yes** | Get private message history |
| `GET` | `/api/matches/history` | **Yes** | Fetch paginated match history |
| `GET` | `/api/matches/:id` | **Yes** | Fetch single match detailed breakdown |
| `GET` | `/api/leaderboard` | No | Fetch global top 50 players by XP and wins |

---

## 4. WebSocket Real-Time Protocol (`/ws`)

### Client-to-Server Messages
- **Authenticate**: `{ "type": "auth", "token": "<jwt_token>" }`
- **Join Room Channel**: `{ "type": "join_room", "roomCode": "5SZQ6" }`
- **Leave Room Channel**: `{ "type": "leave_room", "roomCode": "5SZQ6" }`
- **In-Game Chat**: `{ "type": "game_chat", "roomCode": "5SZQ6", "text": "سڵاو", "emoji": null }`
- **Quick Reaction Emoji**: `{ "type": "quick_reaction", "roomCode": "5SZQ6", "emoji": "🎲" }`
- **Direct Friend Message**: `{ "type": "friend_chat", "friendId": "<user_id>", "text": "دەستپێبکەین؟" }`
- **Auction Bid**: `{ "type": "auction_bid", "roomCode": "5SZQ6", "amount": 250 }`
- **Auction Pass**: `{ "type": "auction_pass", "roomCode": "5SZQ6" }`
- **Trade Propose**: `{ "type": "trade_propose", "roomCode": "5SZQ6", "toPlayerId": "<id>", "fromMoney": 100, ... }`
- **Trade Respond**: `{ "type": "trade_respond", "roomCode": "5SZQ6", "accept": true }`
- **Spectate Room**: `{ "type": "spectate_room", "roomCode": "5SZQ6" }`

### Server-to-Client Broadcast Events
- `auth_ok` — Socket authenticated successfully `{ "type": "auth_ok", "userId": "<id>" }`
- `room_updated` — Player joined, ready state changed, or room settings modified
- `game_started` — Game initialized with board state
- `dice_rolled` — Live dice values broadcast to all clients
- `player_moved` — Position change broadcast
- `landing_resolved` — Landing outcome (buy prompt, rent paid, tax deduction)
- `property_bought` / `property_upgraded` / `property_mortgaged` — Property state changes
- `auction_updated` — New high bid or time extension
- `trade_updated` / `trade_resolved` — Trade offer updates
- `turn_ended` / `turn_timeout_advance` — Turn advance to next player
- `game_chat` / `quick_reaction` / `friend_chat` — Chat message delivery
- `player_disconnected` — Connection loss notification

