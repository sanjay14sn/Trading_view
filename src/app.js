const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const signalRoutes = require('./routes/signalRoutes');
const zerodhaRoutes = require('./routes/zerodhaRoutes');
const errorHandler = require('./middlewares/errorMiddleware');
const { apiLimiter } = require('./middlewares/rateLimitMiddleware');

const app = express();

// 🛡️ Security Middleware
app.use(helmet());
app.use(cors());

// 🚦 Rate Limiting (Applied globally to all API routes)
app.use('/', apiLimiter);

// 📦 Body Parser
app.use(express.json({ limit: '10kb', type: ['application/json', 'text/plain'] }));
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// 🏥 Health Check
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'OK',
        env: config.env,
        timestamp: new Date().toISOString()
    });
});

// 🚀 Routes
app.use('/', signalRoutes);
app.use('/api/zerodha', zerodhaRoutes);

// 🛑 Global Error Handler (Must be last)
app.use(errorHandler);

module.exports = app;
