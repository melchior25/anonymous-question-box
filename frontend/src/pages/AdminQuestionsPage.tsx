import { FormEvent, useEffect, useMemo, useState } from 'react'
import {
  deleteAnsweredQuestions,
  deleteQuestion,
  exportQuestionsCsv,
  getAdminQuestions,
  markQuestionAnswered,
  markQuestionNew
} from '../services/questionApi'
import type { Question } from '../types/question.types'

const PASSWORD_STORAGE_KEY = 'anonymous_question_box_admin_password'

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

function getPublicQuestionLink() {
  return `${window.location.origin}/ask`
}

function AdminQuestionsPage() {
  const [adminPassword, setAdminPassword] = useState(() => {
    return sessionStorage.getItem(PASSWORD_STORAGE_KEY) || ''
  })
  const [passwordInput, setPasswordInput] = useState(adminPassword)
  const [questions, setQuestions] = useState<Question[]>([])
  const [loading, setLoading] = useState(false)
  const [exporting, setExporting] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [successMessage, setSuccessMessage] = useState('')
  const [copyStatus, setCopyStatus] = useState('Copy public link')

  const publicQuestionLink = getPublicQuestionLink()

  const newQuestions = useMemo(() => {
    return questions.filter((question) => !question.answered)
  }, [questions])

  const answeredQuestions = useMemo(() => {
    return questions.filter((question) => question.answered)
  }, [questions])

  async function loadQuestions(password = adminPassword) {
    if (!password) return

    try {
      setLoading(true)
      setErrorMessage('')
      const data = await getAdminQuestions(password)
      setQuestions(data.questions)
      sessionStorage.setItem(PASSWORD_STORAGE_KEY, password)
    } catch (error) {
      setQuestions([])
      setErrorMessage(error instanceof Error ? error.message : 'Could not load questions.')
    } finally {
      setLoading(false)
    }
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const cleanPassword = passwordInput.trim()
    setAdminPassword(cleanPassword)
    await loadQuestions(cleanPassword)
  }

  async function handleCopyPublicLink() {
    try {
      await navigator.clipboard.writeText(publicQuestionLink)
      setCopyStatus('Copied')
      window.setTimeout(() => setCopyStatus('Copy public link'), 1600)
    } catch {
      setCopyStatus(publicQuestionLink)
    }
  }

  async function handleCopyQuestion(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      setSuccessMessage('Question copied.')
      window.setTimeout(() => setSuccessMessage(''), 1400)
    } catch {
      setErrorMessage('Could not copy the question.')
    }
  }

  async function handleExportCsv() {
    try {
      setExporting(true)
      setErrorMessage('')
      await exportQuestionsCsv(adminPassword)
      setSuccessMessage('Questions exported.')
      window.setTimeout(() => setSuccessMessage(''), 1800)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not export questions.')
    } finally {
      setExporting(false)
    }
  }

  async function handleMarkAnswered(questionId: string) {
    try {
      await markQuestionAnswered(questionId, adminPassword)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not update question.')
    }
  }

  async function handleMarkNew(questionId: string) {
    try {
      await markQuestionNew(questionId, adminPassword)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not update question.')
    }
  }

  async function handleDelete(questionId: string) {
    const confirmed = window.confirm('Delete this question? This cannot be undone.')

    if (!confirmed) return

    try {
      await deleteQuestion(questionId, adminPassword)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not delete question.')
    }
  }

  async function handleDeleteAnswered() {
    if (answeredQuestions.length === 0) return

    const confirmed = window.confirm(`Delete ${answeredQuestions.length} answered question${answeredQuestions.length === 1 ? '' : 's'}? This cannot be undone.`)

    if (!confirmed) return

    try {
      const result = await deleteAnsweredQuestions(adminPassword)
      setSuccessMessage(`${result.deletedCount} answered question${result.deletedCount === 1 ? '' : 's'} deleted.`)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not delete answered questions.')
    }
  }

  function handleLogout() {
    sessionStorage.removeItem(PASSWORD_STORAGE_KEY)
    setAdminPassword('')
    setPasswordInput('')
    setQuestions([])
    setErrorMessage('')
    setSuccessMessage('')
  }

  useEffect(() => {
    document.title = 'Anonymous questions admin'

    if (adminPassword) {
      loadQuestions(adminPassword)
    }
  }, [])

  if (!adminPassword) {
    return (
      <main className="admin-page-shell">
        <section className="admin-login-card">
          <div className="eyebrow">Private admin page</div>
          <h1>View anonymous questions</h1>
          <p className="intro">
            Enter the admin password to see submitted questions.
          </p>

          <form className="login-form" onSubmit={handleLogin}>
            <label htmlFor="password">Admin password</label>
            <input
              id="password"
              type="password"
              value={passwordInput}
              placeholder="Enter password"
              onChange={(event) => setPasswordInput(event.target.value)}
            />

            {errorMessage && (
              <p className="error-message">{errorMessage}</p>
            )}

            <button type="submit" className="primary-button">
              Open admin page
            </button>
          </form>

          <div className="setup-note compact-note">
            <strong>First-time setup</strong>
            <p>
              The starter password is change-this-password. Before real use,
              change it with set_admin_password.ps1 in the project folder.
            </p>
          </div>
        </section>
      </main>
    )
  }

  return (
    <main className="admin-page-shell">
      <section className="admin-panel">
        <header className="admin-header">
          <div>
            <div className="eyebrow">Admin dashboard</div>
            <h1>Anonymous questions</h1>
            <p>
              {questions.length} total questions - {newQuestions.length} new
            </p>
          </div>

          <div className="admin-actions">
            <button
              type="button"
              className="secondary-button"
              onClick={handleCopyPublicLink}
            >
              {copyStatus}
            </button>
            <button
              type="button"
              className="secondary-button"
              onClick={() => loadQuestions(adminPassword)}
              disabled={loading}
            >
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
            <button
              type="button"
              className="text-button"
              onClick={handleLogout}
            >
              Lock
            </button>
          </div>
        </header>

        <div className="admin-stats">
          <div className="stat-card">
            <span>Total</span>
            <strong>{questions.length}</strong>
          </div>
          <div className="stat-card">
            <span>New</span>
            <strong>{newQuestions.length}</strong>
          </div>
          <div className="stat-card">
            <span>Answered</span>
            <strong>{answeredQuestions.length}</strong>
          </div>
        </div>

        <div className="setup-note">
          <strong>Public form link</strong>
          <p>
            Share this page with people who need to ask a question:
            <span className="public-link-text">{publicQuestionLink}</span>
          </p>
          <p>
            Email backup can be enabled in Render with SMTP environment variables.
            The Export CSV button gives you a manual backup at any time.
          </p>
        </div>

        <div className="admin-toolbar">
          <div>
            <strong>Question list</strong>
            <span>{newQuestions.length} waiting for review</span>
          </div>

          <div className="admin-actions">
            <button
              type="button"
              className="secondary-button"
              disabled={exporting}
              onClick={handleExportCsv}
            >
              {exporting ? 'Exporting...' : 'Export CSV'}
            </button>

            <button
              type="button"
              className="danger-button"
              disabled={answeredQuestions.length === 0}
              onClick={handleDeleteAnswered}
            >
              Delete answered
            </button>
          </div>
        </div>

        {errorMessage && (
          <p className="error-message">{errorMessage}</p>
        )}

        {successMessage && (
          <p className="success-message">{successMessage}</p>
        )}

        {questions.length === 0 ? (
          <div className="empty-state">
            <h2>No questions yet</h2>
            <p>
              When someone submits a question from the public page, it will appear here.
            </p>
            <a href="/ask" className="inline-link">
              Open public question page
            </a>
          </div>
        ) : (
          <div className="question-list">
            {questions.map((question, index) => (
              <article
                key={question.id}
                className={question.answered ? 'question-card answered' : 'question-card'}
              >
                <div className="question-card-top">
                  <div className="question-meta-group">
                    <span className="question-number">Question {questions.length - index}</span>
                    <span className="date-label">{formatDate(question.createdAt)}</span>
                  </div>
                  <span className={question.answered ? 'status answered-status' : 'status new-status'}>
                    {question.answered ? 'Answered' : 'New'}
                  </span>
                </div>

                <p>{question.text}</p>

                <div className="question-card-actions">
                  <button
                    type="button"
                    className="secondary-button"
                    onClick={() => handleCopyQuestion(question.text)}
                  >
                    Copy text
                  </button>

                  {question.answered ? (
                    <button
                      type="button"
                      className="secondary-button"
                      onClick={() => handleMarkNew(question.id)}
                    >
                      Mark new
                    </button>
                  ) : (
                    <button
                      type="button"
                      className="secondary-button"
                      onClick={() => handleMarkAnswered(question.id)}
                    >
                      Mark answered
                    </button>
                  )}

                  <button
                    type="button"
                    className="danger-button"
                    onClick={() => handleDelete(question.id)}
                  >
                    Delete
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  )
}

export default AdminQuestionsPage