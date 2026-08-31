# RAILWAY PRODUCTION SETUP GUIDE — مۆنۆپۆلی هەولێر (Monopoly Hawler)

Complete, step-by-step guide to configure, deploy, and link the **PostgreSQL Database** and **Backend Web Service** on Railway.

---

## Prerequisites
- Railway Account with access to the project.
- GitHub repository: `https://github.com/alaneng11/monopoly`

---

## Step 1: Open Your Railway Project
1. Navigate to your Railway project dashboard:
   👉 **[Railway Project Console](https://railway.com/project/ef0b9484-7f29-47c6-98b5-6b148ec5fed4)**
2. You will see your existing backend service (`backend` or `monopoly`).

---

## Step 2: Add PostgreSQL Database Plugin (Crucial)

To make PostgreSQL the authoritative production database:

1. In your Railway Project canvas, click the **`+ New`** button (top right or canvas center).
2. Select **Database** → **Add PostgreSQL**.
3. Railway will provision a dedicated PostgreSQL 16 database instance in ~15 seconds.
4. Once created, click on the **PostgreSQL** service card in Railway and go to the **Variables** tab.
5. Notice that Railway provides a variable named `DATABASE_URL` (e.g., `postgresql://postgres:password@postgres.railway.internal:5432/railway`).

---

## Step 3: Link `DATABASE_URL` to the Backend Service

1. Click on your **Backend Web Service** card.
2. Go to the **Variables** tab.
3. Add or update the following environment variables:

| Variable Name | Value / Reference | Purpose |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` *(or copy direct postgres connection string)* | Connects Node.js backend to Railway PostgreSQL |
| `NODE_ENV` | `production` | Enables production mode, SSL, and error shielding |
| `JWT_SECRET` | `hawler_monopoly_secret_key_production_2026_x92` *(or custom 32+ chars)* | Signs player auth tokens |
| `PORT` | `3000` | HTTP & WebSocket server port |

> [!TIP]
> In Railway, you can type `${{` in the value box and choose `Postgres.DATABASE_URL` to link them automatically! When Railway updates the database credentials, your backend stays linked.

---

## Step 4: Configure Build & Deploy Settings

1. Click on the **Backend Service** → **Settings** tab.
2. Under **Build Settings**:
   - **Root Directory**: `backend` *(or leave blank if using root Dockerfile)*.
   - **Builder**: `DOCKERFILE` *(Railway auto-detects `Dockerfile`)*.
3. Under **Networking**:
   - Click **Generate Domain** (if not already created).
   - Example generated domain: `https://backend-production-bdeaa.up.railway.app`

---

## Step 5: Trigger Deployment & Automatic Migrations

1. Go to the **Deployments** tab in your Backend service.
2. Click **Deploy** (or **Redeploy** on the latest commit).
3. The build logs will show:
   ```log
   ✅ PostgreSQL connected: 2026-08-31 16:30:00.000+00
   ✅ Database initialized
   🔄 Running migrations...
   ✅ Migrations done: 43 statements
   🌱 Seeding achievements...
   ✅ Achievements seeded
   🌱 Seeding missions...
   ✅ Missions seeded
   🌱 Seeding daily rewards...
   ✅ Daily rewards seeded
   🌱 Seeding collectibles...
   ✅ Collectibles seeded
   🌱 Seeding seasons...
   ✅ Seasons seeded
   🌱 Seeding cosmetics catalog...
   ✅ Cosmetics seeded
   🎉 Auto-setup complete!
   🏰 مۆنۆپۆلی هەولێر backend v2.0 on port 3000
   ```

---

## Step 6: Verify Production Health & Database

Open the health check endpoint in your web browser:
👉 `https://backend-production-bdeaa.up.railway.app/health`

Expected JSON response:
```json
{
  "status": "ok",
  "service": "hawler-monopoly-backend",
  "version": "2.0.0",
  "timestamp": "2026-08-31T16:30:00.000Z",
  "database": "postgresql",
  "stats": {
    "users": 1
  }
}
```

> [!IMPORTANT]
> If `"database"` shows `"postgresql"`, congratulations! Your game is running against a live, authoritative PostgreSQL cloud database on Railway.

---

## Step 7: Update Flutter Client (If Domain Changed)

If your Railway public domain changed, verify that `hawler_monopoly/lib/data/online/api_client.dart` contains your Railway domain:
```dart
String get baseUrl {
  if (_baseUrl != null) return _baseUrl!;
  if (kIsWeb && (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
    return 'http://localhost:3000';
  }
  return 'https://backend-production-bdeaa.up.railway.app';
}
```
All WebSocket connections will automatically route to `wss://backend-production-bdeaa.up.railway.app/ws`.
