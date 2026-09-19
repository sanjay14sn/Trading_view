const redis = require('../utils/redis');
const { logAction } = require('../utils/logger');

/**
 * Flip Filter Service (Redis-backed)
 * Prevents "Indicator Flipping" by ignoring opposite signals that arrive within a 3-second window.
 */
const flipFilterService = {
    /**
     * @param {Object} signal - { symbol, action, price }
     * @returns {Promise<boolean>} - true if signal should be executed, false if ignored
     */
    async shouldExecute(signal) {
        try {
            const now = Date.now();
            const key = `flip:last:${signal.symbol}`;

            // 1. Fetch last signal state from Redis
            const lastSignalJson = await redis.get(key);
            const currentSignalAction = signal.action.toUpperCase();

            if (lastSignalJson) {
                const lastSignal = JSON.parse(lastSignalJson);
                const isOppositeAction = lastSignal.action !== currentSignalAction;
                const timeDiff = now - lastSignal.timestamp;

                // 2. Logic: If opposite action arrives within 3000ms, ignore it
                if (isOppositeAction && timeDiff < 3000) {
                    logAction('SIGNAL_FLIP_FILTERED', {
                        symbol: signal.symbol,
                        current: currentSignalAction,
                        last: lastSignal.action,
                        diffMs: timeDiff
                    });
                    return false; // Ignore
                }
            }

            // 3. Update Redis with latest signal state (expires after 1 hour to save memory)
            await redis.set(key, JSON.stringify({
                action: currentSignalAction,
                timestamp: now
            }), 'EX', 3600);

            return true; // Execute
        } catch (error) {
            console.error(`Flip Filter Error: ${error.message}`);
            return true; // Fail-safe: execute if Redis is down
        }
    },

    /**
     * Express Middleware wrapper
     */
    middleware() {
        return async (req, res, next) => {
            const signal = req.body;
            const execute = await this.shouldExecute(signal);

            if (!execute) {
                return res.status(200).json({
                    status: "ignored",
                    reason: "indicator_flip_detected",
                    window: "3s"
                });
            }
            next();
        };
    }
};

module.exports = flipFilterService;
