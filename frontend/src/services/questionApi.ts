import type { Question } from '../types/question.types'

function getApiUrl() {
  const configuredApiUrl = (import.meta.env.VITE_API_URL || '').trim()

  if (configuredApiUrl) {
    return configuredApiUrl
  }

  const hostname = window.location.hostname
  const port = window.location.port
  const isLocalDevFrontend = ['5173', '5174', '5175'].includes(port)

  if (isLocalDevFrontend) {
    return `${window.location.protocol}//${hostname}:5000`
  }

  return window.location.origin
}

const API_URL = getApiUrl()

type ApiResult<T> = {
  ok: boolean
  message?: string
} & T

export type EmailStatus = {
  enabled: boolean
  hostSet: boolean
  host: string
  portSet: boolean
  port: string
  secureSet: boolean
  secure: string
  userSet: boolean
  toSet: boolean
  fromSet: boolean
  passSet: boolean
  passLength: number
  publicUrlSet: boolean
  publicUrl: string
}

async function readResponse<T>(response: Response): Promise<ApiResult<T>> {
  const data = await response.json().catch(() => ({}))

  if (!response.ok) {
    throw new Error(data.message || 'Something went wrong.')
  }

  return data
}

function getNetworkErrorMessage() {
  return 'Cannot reach the backend. Make sure the app server is running.'
}

async function requestWithNetworkMessage<T>(request: () => Promise<Response>) {
  try {
    const response = await request()
    return readResponse<T>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}

export async function submitQuestion(question: string) {
  return requestWithNetworkMessage<{ question: { id: string; createdAt: string } }>(() => {
    return fetch(`${API_URL}/api/questions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ question })
    })
  })
}

export async function getAdminQuestions(adminPassword: string) {
  return requestWithNetworkMessage<{ questions: Question[] }>(() => {
    return fetch(`${API_URL}/api/questions/admin`, {
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function getEmailStatus(adminPassword: string) {
  return requestWithNetworkMessage<{ email: EmailStatus }>(() => {
    return fetch(`${API_URL}/api/questions/admin/email-status`, {
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function sendTestEmail(adminPassword: string) {
  return requestWithNetworkMessage<{ messageId: string | null }>(() => {
    return fetch(`${API_URL}/api/questions/admin/test-email`, {
      method: 'POST',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function exportQuestionsCsv(adminPassword: string) {
  const response = await fetch(`${API_URL}/api/questions/admin/export.csv`, {
    headers: {
      'x-admin-password': adminPassword
    }
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.message || 'Could not export questions.')
  }

  const blob = await response.blob()
  const downloadUrl = window.URL.createObjectURL(blob)
  const dateLabel = new Date().toISOString().slice(0, 10)

  const anchor = document.createElement('a')
  anchor.href = downloadUrl
  anchor.download = `anonymous-questions-${dateLabel}.csv`
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()

  window.URL.revokeObjectURL(downloadUrl)
}

export async function markQuestionAnswered(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<{ question: Question }>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}/answered`, {
      method: 'PATCH',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function markQuestionNew(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<{ question: Question }>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}/new`, {
      method: 'PATCH',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function deleteQuestion(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<Record<string, never>>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}`, {
      method: 'DELETE',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function deleteAnsweredQuestions(adminPassword: string) {
  return requestWithNetworkMessage<{ deletedCount: number }>(() => {
    return fetch(`${API_URL}/api/questions/admin/answered`, {
      method: 'DELETE',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}