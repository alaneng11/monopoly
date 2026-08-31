# DISASTER RECOVERY & BACKUP PLAN — مۆنۆپۆلی هەولێر (Monopoly Hawler)

Comprehensive disaster recovery protocols, database backup procedures, failover mechanisms, and emergency incident playbooks for **مۆنۆپۆلی هەولێر**.

---

## 1. Backup Strategy Overview

| Layer | Strategy | Retention | Recovery Time Objective (RTO) | Recovery Point Objective (RPO) |
|---|---|---|---|---|
| **PostgreSQL Database** | Railway Automated Snapshots + Manual `pg_dump` | 7 Days (Railway) / 30 Days (Offsite) | < 15 minutes | < 1 hour |
| **Media / Storage** | Persistent Volume + Offsite Sync | Daily backup | < 30 minutes | < 24 hours |
| **Application State** | Git Version Control (`main` branch) | Permanent | < 5 minutes | 0 (Zero data loss) |

---

## 2. Automated Backups on Railway

Railway PostgreSQL includes automated daily backup snapshots.

### How to Check and Manage Backups in Railway
1. Open your **PostgreSQL service** in the Railway Dashboard.
2. Go to the **Backups** tab.
3. Railway automatically lists daily point-in-time recovery snapshots.
4. Click **Restore** next to any snapshot to restore the database to that exact timestamp.

---

## 3. Manual Database Backup (Ad-Hoc `pg_dump`)

Before major updates or database maintenance, perform a manual export:

```bash
# Set your production database URL
export DATABASE_URL="postgresql://postgres:password@host:port/railway"

# Dump entire database to a compressed SQL file
pg_dump $DATABASE_URL -F c -b -v -f monopoly_backup_$(date +%Y%m%d_%H%M%S).dump

# Or export as plain SQL script
pg_dump $DATABASE_URL > monopoly_backup_$(date +%Y%m%d_%H%M%S).sql
```

---

## 4. Disaster Restore Procedure

In the event of database failure or corrupted state:

### Scenario A: Restore via Railway UI (Fastest)
1. Navigate to **PostgreSQL Service** → **Backups**.
2. Select the snapshot immediately prior to the incident.
3. Click **Restore Snapshot**.
4. Railway provisions a fresh restored instance and reconnects `DATABASE_URL`.
5. Restart the backend service.

### Scenario B: Manual Restore via CLI (`pg_restore`)
```bash
# 1. Terminate active connections
psql $DATABASE_URL -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'railway' AND pid <> pg_backend_pid();"

# 2. Restore from custom-format dump
pg_restore -d $DATABASE_URL --clean --if-exists --no-owner --no-privileges monopoly_backup_latest.dump
```

---

## 5. Emergency Incident Playbooks

### Incident 1: Backend Container Crash / Out of Memory
1. **Symptoms**: `/health` endpoint returns 502/503 or connection timeout.
2. **Immediate Action**:
   - Open Railway Dashboard → Backend Service → **Deployments**.
   - Click **Restart** on the active deployment.
   - Railway spins up a clean container within ~10 seconds.
3. **Investigation**:
   - Check **Deploy Logs** for uncaught exceptions or memory spikes.
   - Verify WebSocket connection counts (`clients.size`).

### Incident 2: Database Connection Saturation
1. **Symptoms**: Server logs show `timeout exceeded when connecting to database` or `too many clients`.
2. **Immediate Action**:
   - Connection pool is capped at `max: 20` clients per container.
   - If lingering connections exist, query active locks in PostgreSQL:
     ```sql
     SELECT pid, age(clock_timestamp(), query_start), usename, query 
     FROM pg_stat_activity 
     WHERE state != 'idle' AND query_start < now() - interval '1 minute';
     ```
   - Terminate stale queries:
     ```sql
     SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction';
     ```

### Incident 3: Frozen Multiplayer Match
1. **Resolution**:
   - The server-side **Turn Timer Scheduler** (`startTurnTimerScheduler`) automatically detects games where a turn has stalled past 30 seconds and auto-advances the turn without requiring manual intervention.
   - If a game needs to be force-closed:
     ```sql
     UPDATE game_rooms SET status = 'closed', finished_at = extract(epoch from now())::bigint WHERE code = 'ROOM_CODE';
     ```

---

## 6. Contacts & Escalation
- **Technical Lead**: alaneng11
- **Platform Provider**: Railway Support ([https://railway.app/help](https://railway.app/help))
- **Status Page**: [https://status.railway.app](https://status.railway.app)
