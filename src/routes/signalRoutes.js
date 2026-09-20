const express = require('express');
const router = express.Router();
const signalController = require('../controllers/signalController');
const tradeController = require('../controllers/tradeController');
const { verifyWebhook } = require('../middlewares/authMiddleware');
const { webhookLimiter } = require('../middlewares/rateLimitMiddleware');
const flipFilter = require('../services/flipFilterService');

// 📡 Webhook Signal Receipt (Protected by HMAC, Rate Limit, and Flip Filter)
router.post('/tradingview-signal',
    webhookLimiter,
    verifyWebhook,
    flipFilter.middleware(),
    signalController.postSignal
);

// 📊 Dashboard & History
router.get('/dashboard', signalController.getDashboard);
router.get('/signals', signalController.getSignals);

// 📱 Push Notification Token Registration
router.post('/api/push-token', signalController.registerPushToken);

// 💼 Trade Management
router.get('/trades', tradeController.getTrades);
router.get('/trades/:id', tradeController.getTradeById);
router.post('/trades/:id/close', tradeController.closeTradeManual);

module.exports = router;
