# مۆنۆپۆلی هەولێر — Railway Deployment Guide

## Problem
Your Railway account is logged in with a different Google/GitHub account than the one that owns `alaneng11/monopoly`. Railway can't access the repo.

## Solution — Fix the GitHub Connection (5 minutes)

### Step 1: Open Railway
Go to: https://railway.app/account

### Step 2: Disconnect wrong GitHub account
1. Click **Integrations** (or **Settings** → **Integrations**)
2. Find the **GitHub** integration
3. Click **Disconnect**

### Step 3: Connect the RIGHT GitHub account
1. Click **Connect GitHub** (or **New Integration**)
2. Log in with the GitHub account: **alaneng11**
3. Authorize Railway to access your repositories

### Step 4: Create the project
1. Go to: https://railway.app/new
2. Click **Deploy from GitHub repo**
3. Select repo: **alaneng11/monopoly**
4. Railway will auto-detect the Dockerfile

### Step 5: Configure the service
1. Click on the **backend** service
2. Go to **Settings**
3. Set **Root Directory** to: `backend`

### Step 6: Set environment variables
Go to **Variables** tab and add:
```
JWT_SECRET=<any long random string — generate one at https://generate-secret.vercel.app/32>
DB_PATH=/data/hawler.db
NODE_ENV=production
```

### Step 7: Deploy
1. Railway will auto-deploy from the main branch
2. Wait for build to complete (~2 minutes)
3. Go to **Settings** → **Networking** → **Generate Domain**
4. Copy the URL (e.g., `https://backend-xxxx.up.railway.app`)

### Step 8: Test
Open in browser: `<your-railway-url>/health`
You should see: `{"status":"ok","service":"hawler-monopoly-backend"}`

## What Was Already Done
- ✅ Backend code written (Node.js + Express + SQLite + WebSocket)
- ✅ GitHub repo pushed: https://github.com/alaneng11/monopoly
- ✅ Dockerfile created in `backend/Dockerfile`
- ✅ 22 API tests passed locally
- ✅ Database with 15+ tables working
- ✅ All env var templates ready
- ❌ Only blocker: Railway ↔ GitHub account mismatch
