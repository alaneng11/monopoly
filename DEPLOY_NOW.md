# Deploy from Railway Dashboard — Do This Now

The Railway API cannot pull latest GitHub commits. You must click Deploy in the dashboard.

## Steps:

1. Go to: https://railway.com/project/ef0b9484-7f29-47c6-98b5-6b148ec5fed4/service/6473de2a-7868-4de2-a21d-98f8415fcde7

2. Click the **Settings** tab on the left sidebar

3. Scroll to **Build Settings** section:
   - Set **Root Directory** to: `backend`
   - Set **Watch Patterns** (if available) to ignore everything except `backend/**`

4. Scroll to **Service Variables** section and make sure these are set:
   - `JWT_SECRET` = any random string (32+ chars)
   - `DB_PATH` = `/app/data/hawler.db`
   - `NODE_ENV` = `production`

5. Go back to **Deployments** tab

6. Click the **Deploy** button (top right corner)

7. Wait for build to complete (~2 minutes)

8. Once deployed, click **Settings** → **Networking** → **Generate Domain**

9. Open: `https://your-generated-url/health`

You should see: `{"status":"ok","service":"hawler-monopoly-backend",...}`
