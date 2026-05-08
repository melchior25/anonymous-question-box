const express = require('express')
const {
  createQuestion,
  getAdminQuestions,
  exportAdminQuestionsCsv,
  markQuestionAnswered,
  markQuestionNew,
  deleteQuestion,
  deleteAnsweredQuestions
} = require('../controllers/questionController')
const { requireAdminPassword } = require('../middleware/adminAuthMiddleware')

const router = express.Router()

router.post('/', createQuestion)
router.get('/admin', requireAdminPassword, getAdminQuestions)
router.get('/admin/export.csv', requireAdminPassword, exportAdminQuestionsCsv)
router.delete('/admin/answered', requireAdminPassword, deleteAnsweredQuestions)
router.patch('/:id/answered', requireAdminPassword, markQuestionAnswered)
router.patch('/:id/new', requireAdminPassword, markQuestionNew)
router.delete('/:id', requireAdminPassword, deleteQuestion)

module.exports = router