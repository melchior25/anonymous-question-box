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

## Storage

Production should use Neon/Postgres:

```text
DATABASE_URL=postgresql://...
```

If `DATABASE_URL` is not set, the app falls back to local JSON storage.

For Render Free, Neon/Postgres is strongly recommended because Render's free filesystem is not reliable for saved questions.

## Render env vars

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-password
QUESTION_COOLDOWN_SECONDS=20
PUBLIC_URL=https://anonymous-question-box.onrender.com
DATABASE_URL=your-neon-connection-string
```

## Health check

Open:

```text
/api/health
```

If Neon is connected correctly, it should show:

```json
"storage": {
  "type": "postgres",
  "ok": true
}
```