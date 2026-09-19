const mongoose = require('mongoose');
const config = require('../config');
const redis = require('../utils/redis');
const Trade = require('../models/Trade');
const mockStore = require('../utils/mockStore');
const { logAction } = require('../utils/logger');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * Risk Manager Module
 * Manages trading limits, concurrent positions, and cooldowns.
 */
const riskManager = {
    /**
     * Comprehensive risk check for a new signal
     */
    async canTrade(signal) {
        const limits = config.risk;

        // 1. Check if trading is globally stopped
        const isStopped = await redis.get('risk:global_stop');
        if (isStopped === 'true') {
            return { allowed: false, reason: 'GLOBAL_STOP_ACTIVE' };
        }



        // 3. Check Daily Trade Count
        const dailyCount = isDbConnected()
            ? await Trade.countDocuments({ entryTime: { $gte: new Date().setHours(0, 0, 0, 0) } })
            : mockStore.getTodayTrades().length;

        if (dailyCount >= limits.maxTradesPerDay) {
            return { allowed: false, reason: 'DAILY_TRADE_LIMIT_REACHED', stats: { dailyCount } };
        }

        // 4. Check Symbol Cooldown (Redis-based)
        const cooldownKey = `risk:cooldown:${signal.symbol}`;
        const inCooldown = await redis.get(cooldownKey);
        if (inCooldown) {
            return { allowed: false, reason: 'SYMBOL_COOLDOWN_ACTIVE' };
        }

        // 5. Daily Loss Limit
        const dailyPnl = await this.getDailyPnl();
        if (dailyPnl <= -limits.maxDailyLoss) {
            return { allowed: false, reason: 'DAILY_LOSS_LIMIT_REACHED', stats: { dailyPnl } };
        }

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

        // Mock Fallback
        const trades = mockStore.getTodayTrades();
        return trades.reduce((sum, t) => sum + (t.pnl || 0), 0);
    },

    /**
     * Start cooldown for a symbol
     */
    async startCooldown(symbol) {
        const cooldownKey = `risk:cooldown:${symbol}`;
        // PX = milliseconds
        await redis.set(cooldownKey, 'true', 'PX', config.risk.tradeCooldownMs);
        logAction('RISK_COOLDOWN_START', { symbol, duration: config.risk.tradeCooldownMs });
    },

    /**
     * Simple stats for dashboard
     */
    async getStats() {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);

        return {
            dailyTrades: isDbConnected() ? await Trade.countDocuments({ entryTime: { $gte: startOfDay } }) : 0,
            activeTrades: isDbConnected() ? await Trade.countDocuments({ status: 'OPEN' }) : 0,
            dailyPnl: await this.getDailyPnl(startOfDay),
            isStopped: (await redis.get('risk:global_stop')) === 'true',
            limits: config.risk
        };
    }
};

module.exports = riskManager;
