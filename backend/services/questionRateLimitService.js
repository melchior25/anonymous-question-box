const submissionTimesByClient = new Map()

function getClientKey(req) {
  const forwardedFor = req.headers['x-forwarded-for']

  if (typeof forwardedFor === 'string' && forwardedFor.trim()) {
    return forwardedFor.split(',')[0].trim()
  }

  return req.ip || req.socket?.remoteAddress || 'unknown-client'
}

function getCooldownSeconds() {
  const parsed = Number(process.env.QUESTION_COOLDOWN_SECONDS || 20)

  if (!Number.isFinite(parsed) || parsed < 0) {
    return 20
  }

  return parsed
}

function getSubmissionCooldownStatus(req) {
  const cooldownSeconds = getCooldownSeconds()

  if (cooldownSeconds === 0) {
    return {
      allowed: true,
      remainingSeconds: 0,
      clientKey: getClientKey(req)
    }
  }

  const clientKey = getClientKey(req)
  const now = Date.now()
  const previousSubmissionTime = submissionTimesByClient.get(clientKey)

  if (!previousSubmissionTime) {
    return {
      allowed: true,
      remainingSeconds: 0,
      clientKey
    }
  }

  const elapsedSeconds = Math.floor((now - previousSubmissionTime) / 1000)
  const remainingSeconds = cooldownSeconds - elapsedSeconds

  if (remainingSeconds > 0) {
    return {
      allowed: false,
      remainingSeconds,
      clientKey
    }
  }

  return {
    allowed: true,
    remainingSeconds: 0,
    clientKey
  }
}

function recordQuestionSubmission(clientKey) {
  submissionTimesByClient.set(clientKey, Date.now())

  if (submissionTimesByClient.size > 500) {
    const oldestKeys = Array.from(submissionTimesByClient.keys()).slice(0, 100)

    oldestKeys.forEach((key) => {
      submissionTimesByClient.delete(key)
    })
  }
}

module.exports = {
  getSubmissionCooldownStatus,
  recordQuestionSubmission
}