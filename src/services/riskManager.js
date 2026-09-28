const mongoose = require('mongoose');
const Trade = require('../models/Trade');
const mockStore = require('../utils/mockStore');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * Risk Manager Module (Disabled / Pass-Through Mode)
 * All signals are allowed directly without limits or cooldowns.
 */
const riskManager = {
    /**
     * Pass-through check for all incoming signals
     */
    async canTrade(signal) {
        return { allowed: true };
    },

    /**
     * Get realized P&L for today
     */
    async getDailyPnl() {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);

        if (isDbConnected()) {
            const trades = await Trade.find({ entryTime: { $gte: startOfDay }, status: { $ne: 'FAILED' } });
            return trades.reduce((sum, t) => sum + (t.pnl || 0), 0);
        }

        const trades = mockStore.getTodayTrades();
        return trades.reduce((sum, t) => sum + (t.pnl || 0), 0);
    },

    /**
     * Start cooldown (No-op since risk management is disabled)
     */
    async startCooldown(symbol) {
        // Disabled
    },

    /**
     * Dashboard statistics summary
     */
    async getStats() {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);

        return {
            dailyTrades: isDbConnected() ? await Trade.countDocuments({ entryTime: { $gte: startOfDay } }) : 0,
            activeTrades: isDbConnected() ? await Trade.countDocuments({ status: 'OPEN' }) : 0,
            dailyPnl: await this.getDailyPnl(),
            isStopped: false,
            limits: { disabled: true }
        };
    }
};

module.exports = riskManager;
