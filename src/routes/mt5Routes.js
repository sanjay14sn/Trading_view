const express = require('express');
const router = express.Router();
const mt5Controller = require('../controllers/mt5Controller');

/**
 * MetaTrader 5 (MT5) Bridge Routes
 * Path prefix: /api/mt5
 */

// Polling endpoint for MT5 EA to fetch pending orders
router.get('/pending-orders', mt5Controller.getPendingOrders);

// Callback after EA executes order on MT5
router.post('/execution-result', mt5Controller.postExecutionResult);

// Callback when position is closed (Manual, Exit signal, SL/TP hit on MT5)
router.post('/trade-closed', mt5Controller.postTradeClosed);

// Account telemetry & heartbeat sync from EA
router.post('/sync', mt5Controller.postSync);

// Health check status endpoint for Mobile App & Dashboard
router.get('/status', mt5Controller.getStatus);

module.exports = router;
