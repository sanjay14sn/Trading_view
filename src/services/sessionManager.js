const redis = require('../utils/redis');
const config = require('../config');
const mt5Service = require('./mt5Service');
const { logError, logAction } = require('../utils/logger');

const TOKEN_KEY = 'mt5:ea_token';

/**
 * Session Manager for MT5 EA Integration
 * Tracks MT5 EA token and connection status.
 */
const sessionManager = {
    /**
     * Get the current EA token from Redis or config
     */
    getEAToken: async () => {
        try {
            const token = await redis.get(TOKEN_KEY);
            return token || config.mt5.eaToken;
        } catch (error) {
            logError(`Error retrieving EA token: ${error.message}`);
            return config.mt5.eaToken;
        }
    },

    /**
     * Store EA token in Redis
     */
    setEAToken: async (token) => {
        try {
            await redis.set(TOKEN_KEY, token, 'EX', 86400 * 30); // 30 days
            logAction('MT5_TOKEN_REFRESH', { success: true });
        } catch (error) {
            logError(`Error saving EA token: ${error.message}`);
        }
    },

    /**
     * Check if MT5 EA has a valid active session
     */
    hasValidSession: async () => {
        return mt5Service.checkConnectionStatus();
    }
};

module.exports = sessionManager;
