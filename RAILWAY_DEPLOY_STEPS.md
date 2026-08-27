# Railway Deployment — Exact Steps

## The Problem
Railway is logged in as `mzurialan3@gmail.com` but your GitHub repo is `alaneng11/monopoly`.
Railway's GitHub integration is connected to a different GitHub account, so it can't see the repo.

## FIX (2 minutes):

### Step 1: Open Railway Integrations
Go to: https://railway.app/account/integrations

### Step 2: Disconnect the wrong GitHub
- Find "GitHub" in the integrations list
- Click "Disconnect" or the X button

### Step 3: Connect the RIGHT GitHub account
- Click "Connect GitHub"
- GitHub login page opens
- **IMPORTANT: Log in as `alaneng11`** (NOT the other account)
- Click "Authorize Railway"
- Done!

### Step 4: Deploy
Go to: https://railway.app/new
- Click "Deploy from GitHub repo"
- Select: `alaneng11/monopoly`
- Railway will detect the Dockerfile

### Step 5: Configure
- Click the **backend** service
- Go to **Settings** → set **Root Directory** to: `backend`
- Go to **Variables** → add:
  - `JWT_SECRET` = `any-random-string-at-least-32-chars`
  - `DB_PATH` = `/data/hawler.db`
  - `NODE_ENV` = `production`

### Step 6: Get your URL
- Go to **Settings** → **Networking** → **Generate Domain**
- Your backend URL will be: `https://backend-xxxxx.up.railway.app`

### Step 7: Test
Open: `https://your-url.up.railway.app/health`
Should show: `{"status":"ok","service":"hawler-monopoly-backend",...}`

---

## Everything is already built and tested:
- ✅ Code on GitHub: https://github.com/alaneng11/monopoly
- ✅ Backend: Node.js + Express + SQLite + WebSocket (22 API tests passed)
- ✅ Database: 15+ tables auto-created
- ✅ Dockerfile: `backend/Dockerfile`
- ✅ railway.json: ready
- ❌ Only blocker: Connect the RIGHT GitHub account to Railway
