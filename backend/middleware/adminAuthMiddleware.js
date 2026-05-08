function requireAdminPassword(req, res, next) {
  const expectedPassword = process.env.ADMIN_PASSWORD

  if (!expectedPassword) {
    return res.status(500).json({
      ok: false,
      message: 'Admin password is not configured.'
    })
  }

  const providedPassword = req.header('x-admin-password')

  if (!providedPassword || providedPassword !== expectedPassword) {
    return res.status(401).json({
      ok: false,
      message: 'Invalid admin password.'
    })
  }

  next()
}

module.exports = {
  requireAdminPassword
}
