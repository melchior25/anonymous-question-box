# Online Deployment Checklist

## Before deployment

- [ ] Run `.\deploy_precheck.ps1`
- [ ] Change the admin password
- [ ] Run `.\build_for_production.ps1`
- [ ] Test `http://localhost:5000/ask`
- [ ] Test `http://localhost:5000/admin/questions`
- [ ] Push project to GitHub

## Render settings

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

Environment variables:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-password
QUESTION_COOLDOWN_SECONDS=20
QUESTION_STORAGE_FILE=/var/data/questions.json
```

Persistent disk:

```text
Mount path: /var/data
```

## After deployment

- [ ] Open `/ask`
- [ ] Submit a test question
- [ ] Open `/admin/questions`
- [ ] Confirm the question appears
- [ ] Mark answered
- [ ] Mark new
- [ ] Delete test question
- [ ] Copy public link