const zerodhaEngine = require('./zerodhaExecutionEngine');
const tradeLifecycle = require('./tradeLifecycleManager');
const { logError, logAction } = require('../utils/logger');
const { addOrderToQueue } = require('../queues/orderQueue');

/**
 * SL Watcher Service
 * Monitors active trades and triggers exits if SL or Target is hit.
 * Also handles EOD square-off at 3:20 PM.
 */
class SLWatcherService {
    constructor() {
        this.interval = null;
        this.POLL_INTERVAL_MS = 2000; // 2 seconds
    }

    /**
     * Start the monitoring loop
     */
    start(io) {
        if (this.interval) return;

        this.interval = setInterval(async () => {
            await this.checkPositions(io);
        }, this.POLL_INTERVAL_MS);

        console.log('👁️  SL Watcher Service started');
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
     * Core monitoring logic
     */
    async checkPositions(io) {
        try {
            const activeTrades = await tradeLifecycle.getActiveTrades();
            if (activeTrades.length === 0) return;

            const symbols = [...new Set(activeTrades.map(t => `NFO:${t.symbol}`))];
            const quotes = await zerodhaEngine.getQuote(symbols);

            for (const trade of activeTrades) {
                const quote = quotes[`NFO:${trade.symbol}`];
                if (!quote) continue;

                const ltp = quote.last_price;
                const isBuy = trade.action.toUpperCase() === 'BUY';

                // 1. Check Stop Loss
                if (trade.sl && (isBuy ? ltp <= trade.sl : ltp >= trade.sl)) {
                    await this.triggerExit(trade, ltp, 'SL_HIT', io);
                }
                // 2. Check Target
                else if (trade.target && (isBuy ? ltp >= trade.target : ltp <= trade.target)) {
                    await this.triggerExit(trade, ltp, 'TARGET_HIT', io);
                }
                // 3. Time-based exit (3:20 PM)
                else if (this.isEOD()) {
                    await this.triggerExit(trade, ltp, 'TIMED_EXIT', io);
                }
            }
        } catch (error) {
            logError(`SL Watcher error: ${error.message}`);
        }
    }

    /**
     * Check if it's past 3:20 PM IST
     */
    isEOD() {
        const now = new Date();
        const istTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
        const hours = istTime.getHours();
        const minutes = istTime.getMinutes();

        return (hours === 15 && minutes >= 20) || hours > 15;
    }

    /**
     * Execute the exit order
     */
    async triggerExit(trade, exitPrice, reason, io) {
        try {
            console.log(`🚨 Triggering ${reason} for ${trade.symbol} at ${exitPrice}`);

            // 1. Add exit order to queue (inverse of entry action)
            const exitAction = trade.action.toUpperCase() === 'BUY' ? 'SELL' : 'BUY';
            await addOrderToQueue({
                symbol: trade.symbol,
                action: exitAction,
                quantity: trade.quantity,
                price: exitPrice
            }, trade._id);

            // 2. Finalize trade record
            await tradeLifecycle.closeTrade(trade._id, exitPrice, reason);

            // 3. Notify dashboard
            if (io) {
                io.emit('trade_closed', {
                    tradeId: trade._id,
                    symbol: trade.symbol,
                    exitPrice,
                    reason,
                    pnl: trade.pnl
                });
            }
        } catch (error) {
            logError(`Failed to trigger exit for ${trade.symbol}: ${error.message}`);
        }
    }
}

module.exports = new SLWatcherService();
