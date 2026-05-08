import AskQuestionPage from './pages/AskQuestionPage'
import AdminQuestionsPage from './pages/AdminQuestionsPage'

function App() {
  const path = window.location.pathname

  if (path === '/admin/questions') {
    return <AdminQuestionsPage />
  }

  return <AskQuestionPage />
}

export default App
