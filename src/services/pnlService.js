const mongoose = require('mongoose');
const Trade = require('../models/Trade');
const PnlDaily = require('../models/PnlDaily');
const mockStore = require('../utils/mockStore');
const { logError, logAction } = require('../utils/logger');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * P&L Service
 * Handles real-time MTM calculations and daily performance reporting.
 */
const pnlService = {
    /**
     * Calculate total P&L for a specific date
     */
    async generateDailyReport(dateStr) {
        try {
            const startOfDay = new Date(dateStr);
            startOfDay.setHours(0, 0, 0, 0);

            const endOfDay = new Date(dateStr);
            endOfDay.setHours(23, 59, 59, 999);

            let trades = [];
            if (isDbConnected()) {
                trades = await Trade.find({
                    exitTime: { $gte: startOfDay, $lte: endOfDay }
                });
            } else {
                trades = mockStore.trades.filter(t => {
                    if (!t.exitTime) return false;
                    const exit = new Date(t.exitTime);
                    return exit >= startOfDay && exit <= endOfDay;
                });
            }

            const stats = trades.reduce((acc, trade) => {
                acc.realizedPnl += trade.pnl || 0;
                acc.totalTrades += 1;
                if (trade.pnl > 0) acc.wins += 1;
                else if (trade.pnl < 0) acc.losses += 1;
                acc.charges += trade.charges || 20; // Assume 20 per order
                return acc;
            }, { realizedPnl: 0, totalTrades: 0, wins: 0, losses: 0, charges: 0 });

            stats.winRate = stats.totalTrades > 0
                ? Math.round((stats.wins / stats.totalTrades) * 100)
                : 0;

            if (isDbConnected()) {
                // Save to PnlDaily collection
                await PnlDaily.findOneAndUpdate(
                    { date: dateStr },
                    { ...stats },
                    { upsert: true, new: true }
                );
            }

            logAction('DAILY_PNL_REPORT_GENERATED', { date: dateStr, pnl: stats.realizedPnl });
            return stats;
        } catch (error) {
            logError(`Error generating daily report: ${error.message}`);
            throw error;
        }
    }
};

module.exports = pnlService;
