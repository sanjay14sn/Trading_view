const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const signalRoutes = require('./routes/signalRoutes');
const zerodhaRoutes = require('./routes/zerodhaRoutes');
const errorHandler = require('./middlewares/errorMiddleware');
const { apiLimiter } = require('./middlewares/rateLimitMiddleware');

const app = express();

// ✅ Trust reverse proxy (nginx) — required for rate-limit & correct IP detection
app.set('trust proxy', 1);

// 🛡️ Security Middleware
app.use(helmet());
app.use(cors());

// ✅ Body Parsing — MUST come before routes so req.body is populated
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: true }));

// 🏥 Health Check (Exempt from rate limiting)
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'OK',
        env: config.env,
        timestamp: new Date().toISOString()
    });
});

// 🚦 Rate Limiting (Applied to remaining API routes)
app.use('/', apiLimiter);

// 🚀 Routes
app.use('/', signalRoutes);
app.use('/api/zerodha', zerodhaRoutes);

// 🛑 Global Error Handler (Must be last)
app.use(errorHandler);

module.exports = app;
