# DEPLOYMENT & LOCAL DEVELOPMENT GUIDE — مۆنۆپۆلی هەولێر (Monopoly Hawler)

---

## PART 1: PRODUCTION DEPLOYMENT (Railway)

### 1. Services Topology
- **Compute Service (`backend`)**: Node.js 20 container running Express & WebSocket on `$PORT`.
- **Database Service (`PostgreSQL`)**: Managed PostgreSQL 16 instance.
- **Storage**: Persistent Disk Volume mounted at `/app/uploads` (or S3-compatible cloud storage).
- **Edge Ingress**: Automatic TLS/SSL termination with public HTTPS and WSS endpoints.

### 2. Environment Variables Matrix
Set in Railway Project Console → **Backend Service** → **Variables**:

| Variable | Recommended Production Value | Required? |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | **YES** (Connects to PostgreSQL) |
| `NODE_ENV` | `production` | **YES** (Enables SSL & security) |
| `JWT_SECRET` | *(Random 32+ char string)* | **YES** (Signs JWT session tokens) |
| `PORT` | `3000` | Optional (Railway injects `$PORT`) |
| `RATE_LIMIT_WINDOW_MS` | `60000` | Optional (Defaults to 60000) |
| `RATE_LIMIT_MAX_REQUESTS` | `120` | Optional (Defaults to 120) |
| `UPLOAD_DIR` | `/app/uploads` | Optional (Defaults to `./uploads`) |

### 3. Automated Deployment & Migrations
On every push to `main` branch or manual **Redeploy** in Railway:
1. Railway builds the image from `backend/Dockerfile` or root `Dockerfile`.
2. `src/index.js` boots and runs `src/auto_setup.js`.
3. Auto-setup applies all 26 table migrations idempotently in PostgreSQL.
4. Auto-setup seeds initial achievements, missions, daily rewards, collectibles, seasons, and cosmetics catalog.
5. Starts HTTP server and WebSocket server on `$PORT`.
6. Health probe checks `GET /health`. If 200 OK, traffic switches with zero downtime.

---

## PART 2: LOCAL DEVELOPMENT (Zero-Config)

### 1. Prerequisites
- Node.js 18+ & npm
- Flutter 3.22+ & Dart SDK
- Google Chrome browser

### 2. Start Backend Locally
```bash
cd backend
npm install
npm run dev
```
- Local server will run on `http://localhost:3000`.
- Automatically initializes local SQLite database in `backend/data.db` (zero PostgreSQL setup required).
- Kurdish dashboard accessible at `http://localhost:3000/`.

### 3. Start Flutter Web Client
```bash
cd hawler_monopoly
flutter pub get
flutter run -d chrome --web-port=5000
```
- Access the web game client at `http://localhost:5000`.
- `ApiClient` automatically detects `localhost:5000` and routes to `http://localhost:3000` and `ws://localhost:3000/ws`.

### 4. Running Local Test Suites
```bash
# Run 30-Scenario Full QA & Multiplayer Stress Suite
node scratch/qa_full_suite.js

# Run Migration DDL Verification
node backend/src/migrate.js

# Run Flutter Analyzer
cd hawler_monopoly
flutter analyze --no-pub
```

