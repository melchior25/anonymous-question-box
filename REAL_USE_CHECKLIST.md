# Anonymous Question Box - Real Use Checklist

Use this checklist before sharing the question form with people.

## 1. Start the app

```powershell
cd C:\Users\boskm\anonymous-question-box
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\start_question_box.ps1
```

Keep that PowerShell window open.

## 2. Check the app

Open a second PowerShell window:

```powershell
cd C:\Users\boskm\anonymous-question-box
.\check_question_box.ps1
```

## 3. Open pages

Public form:

```text
http://localhost:5173/ask
```

Admin page:

```text
http://localhost:5173/admin/questions
```

## 4. Test the full flow

- Open the public form.
- Send a test question.
- Open the admin page.
- Confirm the question appears.
- Copy the question text.
- Mark the question as answered.
- Mark it back to new.
- Delete it.

## 5. Change admin password before real use

```powershell
cd C:\Users\boskm\anonymous-question-box
.\set_admin_password.ps1
```

Restart the app after changing the password.

## 6. Use on another device on the same Wi-Fi

When the app starts, Vite shows a Network URL like:

```text
http://192.168.x.x:5173/
```

Use:

```text
http://192.168.x.x:5173/ask
```

The other device must be on the same Wi-Fi network.

## 7. If ports are stuck

```powershell
cd C:\Users\boskm\anonymous-question-box
.\stop_question_box_ports.ps1
```

Then start again:

```powershell
.\start_question_box.ps1
```

## Notes

- Visitors do not log in.
- Visitors do not enter a name.
- Questions are saved in `backend\data\questions.json`.
- The admin page is protected with the admin password.