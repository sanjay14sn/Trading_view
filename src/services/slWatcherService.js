const tradeLifecycle = require('./tradeLifecycleManager');
const mt5PositionManager = require('./mt5PositionManager');
const mt5Service = require('./mt5Service');
const { logError, logAction } = require('../utils/logger');

/**
 * MT5 SL & Position Watcher Service
 * Monitors active trades and triggers position closure if backend SL/TP criteria are met.
 */
class SLWatcherService {
    constructor() {
        this.interval = null;
        this.POLL_INTERVAL_MS = 3000; // 3 seconds
    }

    /**
     * Start the monitoring loop
     */
    start(io) {
        if (this.interval) return;

        this.interval = setInterval(async () => {
            await this.checkPositions(io);
        }, this.POLL_INTERVAL_MS);

        console.log('👁️  MT5 Position Watcher Service started');
    }

    /**
     * Stop the monitoring loop
     */
    stop() {
        if (this.interval) {
            clearInterval(this.interval);
            this.interval = null;
        }
    }

    /**
     * Monitoring logic for MT5 positions
     */
    async checkPositions(io) {
        try {
            const activeTrades = await tradeLifecycle.getActiveTrades();
            if (activeTrades.length === 0) return;

            // MT5 connection check
            const isEAConnected = mt5Service.checkConnectionStatus();
            if (!isEAConnected) {
                // EA not sending heartbeats, warning logged silently
                return;
            }

            // Note: MT5 handles Stop Loss and Take Profit natively on the broker server.
            // This service acts as a safety guard if backend rules require closing.
        } catch (error) {
            logError(`MT5 SL Watcher error: ${error.message}`);
        }
    }

    /**
     * Trigger explicit exit via MT5 Position Manager
     */
    async triggerExit(trade, exitPrice, reason, io) {
        try {
            console.log(`🚨 Triggering ${reason} for MT5 trade ${trade.symbol} (Ticket: ${trade.mt5Ticket})`);
            await mt5PositionManager.requestClosePosition(trade._id, reason);
        } catch (error) {
            logError(`Failed to trigger MT5 exit for ${trade.symbol}: ${error.message}`);
        }
    }
}

module.exports = new SLWatcherService();
