# Anonymous Question Box

A simple anonymous question app with a public form and private admin page.

## Public page

```text
/ask
```

## Admin page

```text
/admin/questions
```

## Local development

```powershell
cd C:\Users\boskm\anonymous-question-box
.\start_question_box.ps1
```

Local public form:

```text
http://localhost:5173/ask
```

Local admin page:

```text
http://localhost:5173/admin/questions
```

## Local production-style test

```powershell
cd C:\Users\boskm\anonymous-question-box
.\build_for_production.ps1
npm start --prefix backend
```

Then open:

```text
http://localhost:5000/ask
http://localhost:5000/admin/questions
```

## Online deployment

Read:

```text
DEPLOY_RENDER_GUIDE.md
ONLINE_DEPLOYMENT_CHECKLIST.md
```

Recommended Render settings:

Build Command:

```text
npm run render:build
```

Start Command:

```text
npm start
```

Health Check Path:

```text
/api/health
```

Important production env vars:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-password
QUESTION_COOLDOWN_SECONDS=20
QUESTION_STORAGE_FILE=/var/data/questions.json
```

## Storage warning

The current app saves questions in a JSON file.

For online use, use a persistent disk or switch to a real database. Without persistent storage, saved questions can be lost when the service restarts or redeploys.

## Helper scripts

```text
start_question_box.ps1
stop_question_box_ports.ps1
check_question_box.ps1
open_question_box_pages.ps1
set_admin_password.ps1
build_for_production.ps1
deploy_precheck.ps1
```