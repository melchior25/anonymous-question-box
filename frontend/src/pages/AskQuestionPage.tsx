import { FormEvent, useEffect, useMemo, useState } from 'react'
import { submitQuestion } from '../services/questionApi'

const MAX_LENGTH = 1000

function createReference(id: string) {
  return id.split('_').slice(-1)[0]?.slice(0, 6).toUpperCase() || 'VERSTUURD'
}

function formatSentTime(value: string) {
  return new Intl.DateTimeFormat('nl-NL', {
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
    document.title = 'Vragen & Antwoorden'
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
      setErrorMessage('Typ eerst je vraag.')
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
      setErrorMessage(error instanceof Error ? error.message : 'Je vraag kon niet worden verzonden.')
    }
  }

  return (
    <main className="public-page-shell">
      <section className="public-card">
        <div className="public-intro-block">
          <div className="privacy-badge">Geen naam. Geen account. Geen login.</div>

          <div className="eyebrow">Anoniem vragenformulier</div>

          <h1>Vragen &amp; Antwoorden</h1>

          <p className="intro">
            Heb je een vraag? Schrijf die hieronder op. Je hoeft geen naam,
            e-mailadres, gebruikersnaam of andere persoonlijke gegevens in te vullen.
          </p>
        </div>

        <div className="public-info-grid">
          <div className="info-pill">
            <strong>1</strong>
            <span>Typ je vraag</span>
          </div>
          <div className="info-pill">
            <strong>2</strong>
            <span>Verstuur anoniem</span>
          </div>
          <div className="info-pill">
            <strong>3</strong>
            <span>Klaar</span>
          </div>
        </div>

        {status === 'sent' ? (
          <div className="success-panel">
            <div className="success-icon">OK</div>
            <h2>Je vraag is verstuurd.</h2>
            <p>
              Bedankt. Je vraag is anoniem ontvangen.
            </p>

            <div className="sent-reference-card">
              <span>Verzendcode</span>
              <strong>{sentReference}</strong>
              <small>{sentTime}</small>
            </div>

            <button
              type="button"
              className="secondary-button"
              onClick={() => setStatus('idle')}
            >
              Nog een vraag stellen
            </button>
          </div>
        ) : (
          <form className="question-form" onSubmit={handleSubmit}>
            <label htmlFor="question">Jouw vraag</label>

            <textarea
              id="question"
              value={question}
              maxLength={MAX_LENGTH}
              placeholder="Typ hier je vraag..."
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
                {remainingCharacters} tekens over
              </span>
              <span>Houd je vraag duidelijk en respectvol</span>
            </div>

            {status === 'error' && (
              <p className="error-message">{errorMessage}</p>
            )}

            <button
              type="submit"
              className="primary-button"
              disabled={status === 'sending'}
            >
              {status === 'sending' ? 'Versturen...' : 'Anoniem verzenden'}
            </button>
          </form>
        )}

        <p className="footer-note">
          Dit formulier vraagt niet om een naam of account. Alleen je vraag wordt verzonden.
        </p>
      </section>
    </main>
  )
}

export default AskQuestionPage