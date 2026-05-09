const express = require('express')
const cors = require('cors')
const dotenv = require('dotenv')
const os = require('os')
const fs = require('fs')
const path = require('path')
const questionRoutes = require('./routes/questionRoutes')
const { getStorageStatus } = require('./services/questionStorageService')

dotenv.config()

const app = express()
const PORT = process.env.PORT || 5000

app.set('trust proxy', 1)

function getAllowedOrigins() {
  const fallbackOrigin = process.env.FRONTEND_URL || 'http://localhost:5173'
  const configuredOrigins = process.env.FRONTEND_URLS || fallbackOrigin

  return configuredOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
}

function isPrivateNetworkHost(hostname) {
  return (
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname.startsWith('192.168.') ||
    hostname.startsWith('10.') ||
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(hostname)
  )
}

function isAllowedDevelopmentOrigin(origin) {
  if (!origin) return true

  try {
    const parsedOrigin = new URL(origin)
    const allowedPorts = new Set(['5000', '5173', '5174', '5175'])

    return (
      parsedOrigin.protocol === 'http:' &&
      allowedPorts.has(parsedOrigin.port) &&
      isPrivateNetworkHost(parsedOrigin.hostname)
    )
  } catch {
    return false
  }
}

function isAllowedProductionOrigin(origin) {
  if (!origin) return true

  const publicUrl = (process.env.PUBLIC_URL || '').trim()

  if (!publicUrl) {
    return false
  }

  return origin === publicUrl
}

function getRequestOrigin(req) {
  const protocol = req.protocol || 'http'
  const host = req.get('host')

  if (!host) {
    return ''
  }

  return `${protocol}://${host}`
}

function getLocalNetworkAddresses() {
  const interfaces = os.networkInterfaces()
  const addresses = []

  Object.values(interfaces).forEach((networkItems) => {
    if (!Array.isArray(networkItems)) return

    networkItems.forEach((item) => {
      if (item.family === 'IPv4' && !item.internal) {
        addresses.push(item.address)
      }
    })
  })

  return addresses
}

const allowedOrigins = getAllowedOrigins()

app.use((req, res, next) => {
  const sameOrigin = getRequestOrigin(req)

  const dynamicCors = cors({
    origin(origin, callback) {
      if (
        !origin ||
        origin === sameOrigin ||
        allowedOrigins.includes(origin) ||
        isAllowedDevelopmentOrigin(origin) ||
        isAllowedProductionOrigin(origin)
      ) {
        callback(null, true)
        return
      }

      callback(new Error(`CORS blocked origin: ${origin}`))
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'x-admin-password']
  })

  dynamicCors(req, res, next)
})

app.use(express.json({ limit: '30kb' }))

app.get('/api/health', async (req, res) => {
  const storage = await getStorageStatus()

  res.json({
    ok: true,
    app: 'Anonymous Question Box',
    mode: process.env.NODE_ENV || 'development',
    storage,
    timestamp: new Date().toISOString()
  })
})

app.use('/api/questions', questionRoutes)

const frontendDistPath = path.join(__dirname, '..', 'frontend', 'dist')
const frontendIndexPath = path.join(frontendDistPath, 'index.html')

if (fs.existsSync(frontendIndexPath)) {
  app.use(express.static(frontendDistPath))

  app.get(['/', '/ask', '/admin/questions'], (req, res) => {
    res.sendFile(frontendIndexPath)
  })
}

app.use((req, res) => {
  res.status(404).json({
    ok: false,
    message: 'Route not found.'
  })
})

app.use((error, req, res, next) => {
  console.error(error)

  res.status(500).json({
    ok: false,
    message: 'Something went wrong on the server.'
  })
})

app.listen(PORT, () => {
  console.log(`Anonymous Question Box backend running on http://localhost:${PORT}`)
  console.log(`Mode: ${process.env.NODE_ENV || 'development'}`)

  if (fs.existsSync(frontendIndexPath)) {
    console.log('Frontend build detected. Backend is serving the public app.')
  } else {
    console.log('No frontend build detected. Use the Vite frontend during development.')
  }

  console.log(`Allowed configured frontend origins: ${allowedOrigins.join(', ')}`)
  console.log('Same-origin requests are allowed automatically.')
  console.log('Local network backend URLs:')

  const networkAddresses = getLocalNetworkAddresses()

  if (networkAddresses.length === 0) {
    console.log('  No local network address found.')
  } else {
    networkAddresses.forEach((address) => {
      console.log(`  http://${address}:${PORT}`)
    })
  }
})