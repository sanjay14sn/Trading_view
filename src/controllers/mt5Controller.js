const mt5Service = require('../services/mt5Service');
const mt5OrderManager = require('../services/mt5OrderManager');
const mt5PositionManager = require('../services/mt5PositionManager');
const config = require('../config');
const { logError, logAction } = require('../utils/logger');

/**
 * MT5 Controller
 * Express REST API handlers for MetaTrader 5 Expert Advisor (MQL5) communication.
 */
const mt5Controller = {
    /**
     * GET /api/mt5/pending-orders
     * Polled by MT5 EA every 500ms to fetch pending execution and close orders.
     */
    getPendingOrders(req, res) {
        try {
            // Optional EA token check
            const eaToken = req.headers['x-ea-token'] || req.query.token;
            if (config.mt5.eaToken && eaToken && eaToken !== config.mt5.eaToken) {
                return res.status(401).json({ error: 'Unauthorized MT5 EA token' });
            }

            const orders = mt5OrderManager.getPendingOrders();
            res.status(200).json({
                status: 'success',
                count: orders.length,
                orders
            });
        } catch (error) {
            logError(`Error in getPendingOrders: ${error.message}`);
            res.status(500).json({ error: 'Internal Server Error' });
        }
    },

    /**
     * POST /api/mt5/execution-result
     * Called by MT5 EA after calling OrderSend() to report order fill or failure.
     */
    async postExecutionResult(req, res) {
        try {
            const result = req.body || {};
            const updatedTrade = await mt5OrderManager.handleExecutionResult(result);
            res.status(200).json({
                status: 'acknowledged',
                tradeId: updatedTrade ? updatedTrade._id : null
            });
        } catch (error) {
            logError(`Error in postExecutionResult: ${error.message}`);
            res.status(500).json({ error: error.message });
        }
    },

    /**
     * POST /api/mt5/trade-closed
     * Called by MT5 EA when a trade is closed (manual, exit signal, or SL/TP hit).
     */
    async postTradeClosed(req, res) {
        try {
            const closeData = req.body || {};
            const closedTrade = await mt5PositionManager.handleTradeClosed(closeData);
            res.status(200).json({
                status: 'success',
                tradeId: closedTrade ? closedTrade._id : null
            });
        } catch (error) {
            logError(`Error in postTradeClosed: ${error.message}`);
            res.status(500).json({ error: error.message });
        }
    },

    /**
     * POST /api/mt5/sync
     * Called periodically by MT5 EA to report account telemetry & heartbeat.
     */
    postSync(req, res) {
        try {
            const syncData = req.body || {};
            mt5Service.updateState(syncData);
            res.status(200).json({
                status: 'synced',
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logError(`Error in postSync: ${error.message}`);
            res.status(500).json({ error: error.message });
        }
    },

    /**
     * GET /api/mt5/status
     * System status endpoint for Dashboard and Flutter mobile application.
     */
    getStatus(req, res) {
        try {
            const status = mt5Service.getStatus();
            res.status(200).json(status);
        } catch (error) {
            res.status(500).json({ error: error.message });
        }
    }
};

module.exports = mt5Controller;
