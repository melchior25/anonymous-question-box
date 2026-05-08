# Deploy Anonymous Question Box Online with Render

This guide deploys the app as one web service.

The backend serves the built frontend, so the final online links become:

```text
https://your-render-url.onrender.com/ask
https://your-render-url.onrender.com/admin/questions
```

## Important storage note

This app currently stores questions in a JSON file.

For online use, use a persistent disk or change the storage to a real database.

If the host has an ephemeral filesystem, saved questions can be lost when the service restarts or redeploys.

## 1. Build locally first

```powershell
cd C:\Users\boskm\anonymous-question-box
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build_for_production.ps1
```

Then test production-style locally:

```powershell
npm start --prefix backend
```

Open:

```text
http://localhost:5000/ask
http://localhost:5000/admin/questions
```

Stop with `CTRL + C`.

## 2. Push project to GitHub

If this folder is not a Git repo yet:

```powershell
cd C:\Users\boskm\anonymous-question-box
git init
git add .
git commit -m "Prepare anonymous question box for online deployment"
```

Create an empty GitHub repository, then connect it:

```powershell
git remote add origin YOUR_GITHUB_REPO_URL
git branch -M main
git push -u origin main
```

## 3. Create Render Web Service

In Render:

1. Create a new Web Service.
2. Connect the GitHub repository.
3. Use the project root as the root directory.
4. Use this Build Command:

```text
npm run render:build
```

5. Use this Start Command:

```text
npm start
```

6. Use this health check path:

```text
/api/health
```

## 4. Environment variables

Set these in the Render dashboard:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-admin-password
QUESTION_COOLDOWN_SECONDS=20
```

For persistent disk setup, also set:

```text
QUESTION_STORAGE_FILE=/var/data/questions.json
```

## 5. Persistent disk

If using Render persistent disk:

- Mount path: `/var/data`
- Storage file env var: `QUESTION_STORAGE_FILE=/var/data/questions.json`

Without persistent storage, the JSON questions file should not be trusted for real use.

## 6. After deployment

Open:

```text
https://your-render-url.onrender.com/ask
```

Submit a test question.

Then open:

```text
https://your-render-url.onrender.com/admin/questions
```

Use the production admin password from Render environment variables.

## 7. If admin page says it cannot reach backend

Make sure you opened the Render URL, not the local `localhost` URL.

The frontend should call the same Render domain automatically in production.