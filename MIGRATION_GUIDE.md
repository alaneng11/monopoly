# DATABASE MIGRATION GUIDE — مۆنۆپۆلی هەولێر (Monopoly Hawler)

This guide documents the database migration lifecycle, schema versioning, automated bootstrap execution, and best practices for creating and applying schema modifications in **مۆنۆپۆلی هەولێر**.

---

## 1. Migration Architecture

The backend supports **Dual-Engine Migration**:
- **Production Mode (`USE_PG = true`)**: Executes native PostgreSQL DDL (`SERIAL PRIMARY KEY`, `JSONB`, `extract(epoch from now())::bigint`, indices, foreign keys with cascade).
- **Development Mode (`USE_PG = false`)**: Automatically translates SQL for SQLite (`INTEGER PRIMARY KEY AUTOINCREMENT`, `TEXT`, `unixepoch()`).

### Execution Modes
1. **Automated On-Boot Migration**:
   - `src/auto_setup.js` executes inside `index.js` during server startup.
   - Idempotent: uses `CREATE TABLE IF NOT EXISTS`, `CREATE INDEX IF NOT EXISTS`, and safe `ON CONFLICT` clauses.
   - Automatically seeds default catalog items (achievements, missions, daily rewards, collectibles, seasons, cosmetics) if empty.
2. **Explicit CLI Migration**:
   - Run manually via `npm run migrate` (executes `node src/migrate.js`).
   - Run seeders independently via `npm run seed` (executes `node src/seed.js`).

---

## 2. CLI Migration Commands

| Action | Command | Target Database |
|---|---|---|
| **Run Full Migration** | `npm run migrate` | Reads `DATABASE_URL` (PostgreSQL) or `./data.db` (SQLite) |
| **Run Seed Data** | `npm run seed` | Seeds catalog items if not present |
| **Start Server with Auto-Setup** | `npm start` | Runs DB check, auto-migrates, seeds, starts HTTP + WS |
| **Direct Remote Migration** | `DATABASE_URL="postgres://..." node src/migrate.js` | Direct migration on remote Railway DB |

---

## 3. Creating a New Migration

When introducing a new feature that requires a schema change (e.g., adding a new column or table):

### Rule 1: Always Keep Migrations Idempotent
Never use raw `CREATE TABLE` or `ALTER TABLE` without safety checks.

#### For New Tables:
```sql
CREATE TABLE IF NOT EXISTS user_tournaments (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_user_tournaments_score ON user_tournaments(score DESC);
```

#### For Adding Columns to Existing Tables:
In PostgreSQL:
```sql
ALTER TABLE game_states ADD COLUMN IF NOT EXISTS turn_started_at BIGINT;
```
In SQLite fallback (using PRAGMA check in `index.js` or `auto_setup.js`):
```javascript
try {
  await run('ALTER TABLE game_states ADD COLUMN IF NOT EXISTS turn_started_at BIGINT');
} catch (_) {
  // SQLite compatibility check
  const cols = await query("PRAGMA table_info(game_states)");
  if (!cols.some(c => c.name === 'turn_started_at')) {
    await run('ALTER TABLE game_states ADD COLUMN turn_started_at BIGINT');
  }
}
```

### Rule 2: Update Both `migrate.js` and `auto_setup.js`
1. Add the table definition to `UP` in `backend/src/migrate.js`.
2. Add the table definition to `UP` in `backend/src/auto_setup.js`.
3. Add seeder logic in `backend/src/seed.js` if default rows are needed.
4. Update `DATABASE.md` to reflect new columns and constraints.

---

## 4. Rollback & Disaster Recovery Procedures

### Rolling Back a Migration
1. Because migrations are designed to be backward compatible (additive), rolling back a deployment generally does not require dropping newly created columns.
2. If a table must be dropped manually in emergency maintenance:
   ```sql
   DROP TABLE IF EXISTS table_name CASCADE;
   ```
3. Always take a snapshot backup before running destructive DDL on production (see [DISASTER_RECOVERY.md](file:///c:/Users/aland/Desktop/monopoly-main/DISASTER_RECOVERY.md)).
