const mongoose = require('mongoose');
const Trade = require('../models/Trade');
const Signal = require('../models/Signal');
const { logError, logAction } = require('../utils/logger');
const mockStore = require('../utils/mockStore');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * Trade Lifecycle Manager
 * Tracks the state of every trade from signal to exit.
 */
const tradeLifecycleManager = {
    /**
     * Create a new trade record in PENDING state
     */
    async initiateTrade(signalId, symbol, action, quantity, price) {
        const initialData = {
            signalId,
            symbol,
            action,
            quantity,
            entryPrice: price,
            status: 'PENDING',
            createdAt: new Date()
        };

        try {
            if (isDbConnected()) {
                const trade = await Trade.create(initialData);
                if (signalId && mongoose.Types.ObjectId.isValid(signalId)) {
                    await Signal.findByIdAndUpdate(signalId, { tradeId: trade._id });
                }
                return trade;
            }

            // Mock Fallback
            const mockTrade = { ...initialData, _id: `mock_tr_${Date.now()}` };
            mockStore.trades.push(mockTrade);
            return mockTrade;

        } catch (error) {
            logError(`Error initiating trade: ${error.message}`, { signalId, symbol });
            throw error;
        }
    },

    /**
     * Update trade status and metadata
     */
    async updateTrade(tradeId, updates) {
        try {
            if (isDbConnected() && mongoose.Types.ObjectId.isValid(tradeId)) {
                const trade = await Trade.findByIdAndUpdate(tradeId, updates, { new: true });
                if (trade) {
                    logAction('TRADE_STATUS_UPDATE', { tradeId, status: trade.status });
                    return trade;
                }
            }

            // Mock Fallback
            let trade = mockStore.trades.find(t => t._id === tradeId);
            if (!trade) {
                trade = {
                    _id: tradeId,
                    symbol: updates.symbol || 'NIFTY FUT',
                    action: updates.action || 'BUY',
                    quantity: updates.quantity || 50,
                    entryPrice: updates.entryPrice || 0,
                    status: 'PENDING',
                    createdAt: new Date()
                };
                mockStore.trades.push(trade);
            }
            Object.assign(trade, updates);
            logAction('TRADE_STATUS_UPDATE', { tradeId, status: trade.status });
            return trade;

        } catch (error) {
            logError(`Error updating trade: ${error.message}`, { tradeId, updates });
            throw error;
        }
    },

    /**
     * Finish a trade, calculate P&L, and update status
     */
    async closeTrade(tradeId, exitPrice, reason) {
        try {
            let trade;
            if (isDbConnected() && mongoose.Types.ObjectId.isValid(tradeId)) {
                trade = await Trade.findById(tradeId);
            } else {
                trade = mockStore.trades.find(t => t._id === tradeId);
            }

            if (!trade) throw new Error(`Trade ${tradeId} not found`);

            const isBuy = trade.action ? trade.action.toUpperCase() === 'BUY' : true;
            const pnl = isBuy
                ? (exitPrice - (trade.entryPrice || 0)) * (trade.quantity || 1)
                : ((trade.entryPrice || 0) - exitPrice) * (trade.quantity || 1);

            const finalUpdates = {
                exitPrice,
                exitTime: new Date(),
                status: reason,
                pnl: Math.round(pnl * 100) / 100
            };

            if (isDbConnected() && mongoose.Types.ObjectId.isValid(tradeId)) {
                Object.assign(trade, finalUpdates);
                await trade.save();
            } else {
                Object.assign(trade, finalUpdates);
            }

            logAction('TRADE_CLOSED', { tradeId, pnl: trade.pnl, reason });
            return trade;

        } catch (error) {
            logError(`Error closing trade: ${error.message}`, { tradeId, exitPrice, reason });
            throw error;
        }
    },

    /**
     * Get all currently OPEN trades for the monitor
     */
    async getActiveTrades() {
        if (isDbConnected()) {
            return await Trade.find({ status: 'OPEN' });
        }
        // Mock Fallback
        return mockStore.trades.filter(t => t.status === 'OPEN' || t.status === 'PENDING');
    }
};

module.exports = tradeLifecycleManager;
