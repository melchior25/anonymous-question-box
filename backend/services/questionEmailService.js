const nodemailer = require('nodemailer')

function isEmailEnabled() {
  return String(process.env.QUESTION_EMAIL_ENABLED || '').toLowerCase() === 'true'
}

function getBooleanEnv(name, fallback = false) {
  const value = String(process.env[name] || '').toLowerCase()

  if (value === 'true') return true
  if (value === 'false') return false

  return fallback
}

function getReference(id) {
  if (typeof id !== 'string') return 'UNKNOWN'
  return id.split('_').slice(-1)[0]?.slice(0, 6).toUpperCase() || 'UNKNOWN'
}

function getPublicUrl() {
  return (process.env.PUBLIC_URL || '').trim()
}

function getTransportConfig() {
  const host = (process.env.SMTP_HOST || '').trim()
  const port = Number(process.env.SMTP_PORT || 587)
  const secure = getBooleanEnv('SMTP_SECURE', port === 465)
  const user = (process.env.SMTP_USER || '').trim()
  const pass = (process.env.SMTP_PASS || '').trim()

  if (!host || !port || !user || !pass) {
    return null
  }

  return {
    host,
    port,
    secure,
    auth: {
      user,
      pass
    }
  }
}

function createPlainTextEmail(question) {
  const reference = getReference(question.id)
  const createdAt = new Date(question.createdAt).toLocaleString('en')
  const publicUrl = getPublicUrl()
  const adminUrl = publicUrl ? `${publicUrl}/admin/questions` : ''

  return [
    'New anonymous question received',
    '',
    `Reference: ${reference}`,
    `Date: ${createdAt}`,
    '',
    'Question:',
    question.text,
    '',
    adminUrl ? `Admin page: ${adminUrl}` : ''
  ].filter(Boolean).join('\n')
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

function createHtmlEmail(question) {
  const reference = getReference(question.id)
  const createdAt = new Date(question.createdAt).toLocaleString('en')
  const publicUrl = getPublicUrl()
  const adminUrl = publicUrl ? `${publicUrl}/admin/questions` : ''

  return `
    <div style="font-family: Arial, sans-serif; max-width: 680px; color: #111827;">
      <p style="font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; color: #875f2d; font-weight: 700;">
        Anonymous Question Box
      </p>
      <h1 style="font-size: 24px; margin: 0 0 16px;">New anonymous question</h1>
      <div style="background: #f7f1e7; border-radius: 14px; padding: 14px 16px; margin-bottom: 16px;">
        <p style="margin: 0;"><strong>Reference:</strong> ${escapeHtml(reference)}</p>
        <p style="margin: 6px 0 0;"><strong>Date:</strong> ${escapeHtml(createdAt)}</p>
      </div>
      <div style="border: 1px solid #e5e7eb; border-radius: 16px; padding: 18px; background: #ffffff;">
        <p style="margin: 0 0 8px; color: #6b7280; font-size: 13px; font-weight: 700;">Question</p>
        <p style="margin: 0; line-height: 1.6; white-space: pre-wrap;">${escapeHtml(question.text)}</p>
      </div>
      ${
        adminUrl
          ? `<p style="margin-top: 18px;"><a href="${escapeHtml(adminUrl)}" style="color: #111827; font-weight: 700;">Open admin page</a></p>`
          : ''
      }
    </div>
  `
}

async function sendQuestionEmailNotification(question) {
  if (!isEmailEnabled()) {
    return {
      skipped: true,
      reason: 'Email notifications are disabled.'
    }
  }

  const transportConfig = getTransportConfig()

  if (!transportConfig) {
    console.warn('Question email notification skipped: SMTP settings are incomplete.')
    return {
      skipped: true,
      reason: 'SMTP settings are incomplete.'
    }
  }

  const to = (process.env.QUESTION_EMAIL_TO || '').trim()
  const from = (process.env.QUESTION_EMAIL_FROM || process.env.SMTP_USER || '').trim()
  const subject = (process.env.QUESTION_EMAIL_SUBJECT || 'New anonymous question received').trim()

  if (!to || !from) {
    console.warn('Question email notification skipped: QUESTION_EMAIL_TO or QUESTION_EMAIL_FROM missing.')
    return {
      skipped: true,
      reason: 'Recipient or sender missing.'
    }
  }

  const transporter = nodemailer.createTransport(transportConfig)

  await transporter.sendMail({
    from,
    to,
    subject,
    text: createPlainTextEmail(question),
    html: createHtmlEmail(question)
  })

  return {
    skipped: false
  }
}

module.exports = {
  sendQuestionEmailNotification
}