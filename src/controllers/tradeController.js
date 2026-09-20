const mongoose = require('mongoose');
const Trade = require('../models/Trade');
const mockStore = require('../utils/mockStore');
const tradeLifecycle = require('../services/tradeLifecycleManager');
const zerodhaEngine = require('../services/zerodhaExecutionEngine');
const { logError } = require('../utils/logger');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * Trade Controller
 */
const tradeController = {
    async getTrades(req, res) {
        try {
            const { status } = req.query;
            let trades;
            if (isDbConnected()) {
                const query = status ? { status } : {};
                trades = await Trade.find(query).sort({ entryTime: -1 }).limit(100);
            } else {
                trades = status ? mockStore.trades.filter(t => t.status === status) : mockStore.trades;
            }
            res.json(trades);
        } catch (error) { res.status(500).json({ error: error.message }); }
    },

    async getTradeById(req, res) {
        try {
            const { id } = req.params;
            let trade;
            if (isDbConnected() && mongoose.Types.ObjectId.isValid(id)) {
                trade = await Trade.findById(id);
            } else {
                trade = mockStore.trades.find(t => t._id === id);
            }
            if (!trade) return res.status(404).json({ error: 'Trade not found' });
            res.json(trade);
        } catch (error) { res.status(500).json({ error: error.message }); }
    },

    async closeTradeManual(req, res) {
        try {
            const { id } = req.params;
            let trade;

            if (isDbConnected() && mongoose.Types.ObjectId.isValid(id)) {
                trade = await Trade.findById(id);
            } else {
                trade = mockStore.trades.find(t => t._id === id);
            }

            if (!trade || trade.status !== 'OPEN') {
                return res.status(400).json({ error: 'Trade not found or already closed' });
            }

            // In Mock mode, we just simulate closing
            if (!isDbConnected()) {
                trade.status = 'CLOSED';
                trade.exitPrice = trade.entryPrice + 10; // dummy win
                trade.exitTime = new Date();
                trade.pnl = 500;
                return res.json({ status: 'closed_mock', symbol: trade.symbol, pnl: 500 });
            }

            // Real exit logic...
            const quotes = await zerodhaEngine.getQuote([`NFO:${trade.symbol}`]);
            const ltp = quotes[`NFO:${trade.symbol}`].last_price;
            const slWatcher = require('../services/slWatcherService');
            await slWatcher.triggerExit(trade, ltp, 'MANUAL_EXIT', req.app.get('io'));

            res.json({ status: 'exit_triggered', symbol: trade.symbol });
        } catch (error) { res.status(500).json({ error: error.message }); }
    },

    async deleteTrade(req, res) {
        try {
            const { id } = req.params;
            const Signal = require('../models/Signal');
            if (isDbConnected() && mongoose.Types.ObjectId.isValid(id)) {
                const tradeDoc = await Trade.findByIdAndDelete(id);
                if (tradeDoc && tradeDoc.signalId) {
                    await Signal.findByIdAndDelete(tradeDoc.signalId);
                }
                await Signal.deleteMany({ tradeId: id });
                await Signal.findByIdAndDelete(id);
            }
            mockStore.trades = mockStore.trades.filter(t => String(t._id) !== String(id));
            mockStore.signals = mockStore.signals.filter(s => String(s._id) !== String(id) && String(s.tradeId) !== String(id));
            res.json({ status: 'success', message: 'Trade deleted successfully', id });
        } catch (error) {
            logError(`Failed to delete trade ${req.params.id}: ${error.message}`);
            res.status(500).json({ error: error.message });
        }
    },

    async clearAllTrades(req, res) {
        try {
            const Signal = require('../models/Signal');
            if (isDbConnected()) {
                await Trade.deleteMany({});
                await Signal.deleteMany({});
            }
            mockStore.trades = [];
            mockStore.signals = [];
            res.json({ status: 'success', message: 'All trade reports cleared' });
        } catch (error) {
            logError(`Failed to clear trades: ${error.message}`);
            res.status(500).json({ error: error.message });
        }
    }
};

module.exports = tradeController;
