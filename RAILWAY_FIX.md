# FIX: Railway Stuck on Old Commit

Railway is deploying commit `3a67c1e` (the first commit) and can't pull newer ones.

## Do these 3 steps in the Railway Dashboard:

### 1. Check the Build Logs
Go to: https://railway.com/project/ef0b9484-7f29-47c6-98b5-6b148ec5fed4/service/6473de2a-7868-4de2-a21d-98f8415fcde7/deployments

Click the latest FAILED deployment → **View Build Logs**

Tell me what error you see.

### 2. Set Root Directory (Critical!)
In the service page:
1. Click **Settings** tab
2. Scroll to **Build Settings**
3. Set **Root Directory** to: `backend`
4. Save

### 3. Force Deploy from Latest
In the service page:
1. Click **Deployments** tab
2. Click **Deploy** button (top right)
3. Wait for build

If it still fails, click the deployment and check the build logs for the exact error.
