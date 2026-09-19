const redis = require('../utils/redis');
const config = require('../config');
const { logError, logAction } = require('../utils/logger');

const TOKEN_KEY = 'zerodha:access_token';

/**
 * Session Manager for Zerodha Kite API
 * Handles storage and retrieval of daily access tokens in Redis.
 */
const sessionManager = {
    /**
     * Get the current access token from Redis
     */
    getAccessToken: async () => {
        try {
            const token = await redis.get(TOKEN_KEY);
            console.log(`[Session] Retrieval: ${token ? 'SUCCESS ✅' : 'NOT FOUND ❌'} (Using ${redis.isMock ? 'MOCK' : 'REAL'} Redis)`);
            return token;
        } catch (error) {
            logError(`Error retrieving access token: ${error.message}`);
            return null;
        }
    },

    /**
     * Store a new access token in Redis (valid for 24h)
     */
    setAccessToken: async (token) => {
        try {
            await redis.set(TOKEN_KEY, token, 'EX', 86400); // 24 hours
            logAction('ZERODHA_TOKEN_REFRESH', { success: true });
            console.log(`✅ [Session] Saved token to ${redis.isMock ? 'MOCK' : 'REAL'} Redis`);
        } catch (error) {
            logError(`Error saving access token: ${error.message}`);
        }
    },

    /**
     * Check if we have a valid session
     */
    hasValidSession: async () => {
        const token = await redis.get(TOKEN_KEY);
        return !!token;
    }
};

module.exports = sessionManager;
