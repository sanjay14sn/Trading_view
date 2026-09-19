const redis = require('../utils/redis');
const { logAction } = require('../utils/logger');

/**
 * Signal De-duplication Service (Redis-backed)
 * Prevents identical signals within a 5-second window using atomic Redis keys.
 */
const deduplicationService = {
    async isDuplicate(signal) {
        try {
            // Create a unique key for this symbol/action/price combination
            const key = `dedup:${signal.symbol}:${signal.action}:${signal.price}`;

            // Try to set key only if it doesn't exist (NX) with 5s expiry (EX)
            const result = await redis.set(key, '1', 'NX', 'EX', 5);

            const isDup = result === null;

            if (isDup) {
                logAction('SIGNAL_DEDUPLICATED', { symbol: signal.symbol, action: signal.action });
            }

            return isDup;
        } catch (error) {
            console.error(`Deduplication error: ${error.message}`);
            return false; // Fail open to avoid missing trades on Redis error
        }
    }
};

module.exports = deduplicationService;
