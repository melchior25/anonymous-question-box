# Neon Database Setup for Anonymous Question Box

Use this so questions are saved permanently even when Render Free sleeps, restarts, or redeploys.

## 1. Get your Neon connection string

In Neon:

1. Open your Neon project.
2. Click **Connect**.
3. Select your branch, database, and role.
4. Copy the connection string.
5. Use the pooled connection string if Neon shows one by default.

It should look like:

```text
postgresql://user:password@host/database?sslmode=require
```

## 2. Add it to Render

In Render:

```text
anonymous-question-box -> Environment
```

Add:

```text
DATABASE_URL=your-neon-connection-string
```

Keep your existing variables:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-password
QUESTION_COOLDOWN_SECONDS=20
PUBLIC_URL=https://anonymous-question-box.onrender.com
```

## 3. Redeploy

In Render:

```text
Manual Deploy -> Deploy latest commit
```

## 4. Confirm database storage

Open:

```text
https://anonymous-question-box.onrender.com/api/health
```

You should see:

```json
"storage": {
  "type": "postgres",
  "ok": true
}
```

## 5. Test

1. Open `/ask`
2. Submit a question
3. Open `/admin/questions`
4. Confirm the question appears
5. Redeploy or wait for Render to sleep/wake
6. Confirm the question is still there