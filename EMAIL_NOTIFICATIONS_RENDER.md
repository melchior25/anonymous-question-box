# Email Notifications for Anonymous Question Box

This app can send an email every time someone submits a question.

This is useful on Render Free, because questions are stored in a JSON file and may be lost after redeploys or service restarts.

## Render environment variables

Add these to your Render service:

```text
QUESTION_EMAIL_ENABLED=true
QUESTION_EMAIL_TO=your-email@example.com
QUESTION_EMAIL_FROM=your-email@example.com
QUESTION_EMAIL_SUBJECT=New anonymous question received

SMTP_HOST=smtp.gmail.com
SMTP_PORT=465
SMTP_SECURE=true
SMTP_FAMILY=4
SMTP_USER=your-email@example.com
SMTP_PASS=your-16-digit-app-password-without-spaces

PUBLIC_URL=https://anonymous-question-box.onrender.com
```

## Why SMTP_FAMILY=4 matters

Render may try Gmail SMTP through IPv6. If the log shows `ENETUNREACH` with an IPv6 address, force IPv4 with:

```text
SMTP_FAMILY=4
```

## Gmail notes

Do not use your normal Gmail password.

For Gmail SMTP, use a Google App Password.

Usually this requires:

- 2-Step Verification enabled on your Google account
- a generated App Password
- the App Password pasted into Render as `SMTP_PASS`

When pasting the app password, remove spaces.

Example:

```text
abcd efgh ijkl mnop
```

becomes:

```text
abcdefghijklmnop
```

## After adding variables

In Render:

```text
Manual Deploy -> Deploy latest commit
```

Then open the admin page and click:

```text
Send test email
```

Check your inbox and spam folder.

## Manual backup

The admin page also has an Export CSV button.
Use it regularly during the 2-3 day question collection period.