import { FormEvent, useEffect, useMemo, useState } from 'react'
import { submitQuestion } from '../services/questionApi'

const MAX_LENGTH = 1000

function createReference(id: string) {
  return id.split('_').slice(-1)[0]?.slice(0, 6).toUpperCase() || 'SENT'
}

function formatSentTime(value: string) {
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

function AskQuestionPage() {
  const [question, setQuestion] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [errorMessage, setErrorMessage] = useState('')
  const [sentReference, setSentReference] = useState('')
  const [sentTime, setSentTime] = useState('')

  useEffect(() => {
    document.title = 'Ask anonymously'
    document.body.classList.add('ask-page-active')

    return () => {
      document.body.classList.remove('ask-page-active')
    }
  }, [])

  const remainingCharacters = useMemo(() => {
    return MAX_LENGTH - question.length
  }, [question])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const cleanQuestion = question.trim()

    if (!cleanQuestion) {
      setStatus('error')
      setErrorMessage('Please type your question first.')
      return
    }

    try {
      setStatus('sending')
      setErrorMessage('')
      const result = await submitQuestion(cleanQuestion)
      setSentReference(createReference(result.question.id))
      setSentTime(formatSentTime(result.question.createdAt))
      setQuestion('')
      setStatus('sent')
    } catch (error) {
      setStatus('error')
      setErrorMessage(error instanceof Error ? error.message : 'Could not send your question.')
    }
  }

  return (
    <main className="public-page-shell">
      <section className="public-card">
        <div className="privacy-badge">No name. No account. No login.</div>

        <div className="eyebrow">Anonymous question box</div>

        <h1>Ask your question anonymously</h1>

        <p className="intro">
          Write your question in the box below. You do not need to add your name,
          email address, username, or any personal information.
        </p>

        <div className="public-info-grid">
          <div className="info-pill">
            <strong>1</strong>
            <span>Type your question</span>
          </div>
          <div className="info-pill">
            <strong>2</strong>
            <span>Send anonymously</span>
          </div>
          <div className="info-pill">
            <strong>3</strong>
            <span>Done</span>
          </div>
        </div>

        {status === 'sent' ? (
          <div className="success-panel">
            <div className="success-icon">OK</div>
            <h2>Your question has been sent.</h2>
            <p>
              Thank you. Your question was received anonymously.
            </p>

            <div className="sent-reference-card">
              <span>Sent reference</span>
              <strong>{sentReference}</strong>
              <small>{sentTime}</small>
            </div>

            <button
              type="button"
              className="secondary-button"
              onClick={() => setStatus('idle')}
            >
              Ask another question
            </button>
          </div>
        ) : (
          <form className="question-form" onSubmit={handleSubmit}>
            <label htmlFor="question">Your question</label>

            <textarea
              id="question"
              value={question}
              maxLength={MAX_LENGTH}
              placeholder="Type your question here..."
              onChange={(event) => {
                setQuestion(event.target.value)

                if (status === 'error') {
                  setStatus('idle')
                  setErrorMessage('')
                }
              }}
            />

            <div className="form-row">
              <span className={remainingCharacters < 80 ? 'danger-count' : ''}>
                {remainingCharacters} characters left
              </span>
              <span>Keep it respectful and clear</span>
            </div>

            {status === 'error' && (
              <p className="error-message">{errorMessage}</p>
            )}

            <button
              type="submit"
              className="primary-button"
              disabled={status === 'sending'}
            >
              {status === 'sending' ? 'Sending...' : 'Send anonymously'}
            </button>
          </form>
        )}

        <p className="footer-note">
          This page only sends your question. It does not ask for a name or account.
        </p>
      </section>
    </main>
  )
}

export default AskQuestionPage