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
EMAIL_NOTIFICATIONS_RENDER.md
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
PUBLIC_URL=https://anonymous-question-box.onrender.com
```

Optional email notification env vars:

```text
QUESTION_EMAIL_ENABLED=true
QUESTION_EMAIL_TO=your-email@example.com
QUESTION_EMAIL_FROM=your-email@example.com
QUESTION_EMAIL_SUBJECT=New anonymous question received
SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=your-email@example.com
SMTP_PASS=your-16-digit-app-password-without-spaces
```

## Storage warning

The current app saves questions in a JSON file.

On Render Free, redeploys/restarts can clear saved questions. Use the email notification feature and Export CSV button for backups.

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