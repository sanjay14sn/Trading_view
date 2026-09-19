const KiteConnect = require('kiteconnect').KiteConnect;
const config = require('../config');
const sessionManager = require('../services/sessionManager');
const { logError, logAction } = require('../utils/logger');

const kite = new KiteConnect({
    api_key: config.zerodha.apiKey
});

/**
 * Zerodha Controller
 * Handles authentication and session management for Kite Connect
 */
const zerodhaController = {
    /**
     * Redirect user to Zerodha Login page
     */
    initiateLogin: (req, res) => {
        try {
            const loginUrl = kite.getLoginURL();
            logAction('ZERODHA_LOGIN_INITIATED', { url: loginUrl });
            res.redirect(loginUrl);
        } catch (error) {
            logError(`Failed to initiate Zerodha login: ${error.message}`);
            res.status(500).json({ error: 'Failed to initiate login flow' });
        }
    },

    /**
     * Handle Redirect from Zerodha
     * Exchanges request_token for access_token
     */
    handleCallback: async (req, res) => {
        const { request_token } = req.query;
        console.log(`\n--- Zerodha Callback Received ---`);
        console.log(`Token: ${request_token ? 'Present' : 'MISSING'}`);

        if (!request_token) {
            console.error('❌ Callback failed: request_token is missing');
            return res.status(400).json({ error: 'Request token is missing' });
        }

        try {
            console.log('🔄 Exchanging request_token for access_token...');
            const session = await kite.generateSession(request_token, config.zerodha.apiSecret);

            console.log(`✅ Session generated for user: ${session.user_id}`);

            // Store access token in Redis via sessionManager
            await sessionManager.setAccessToken(session.access_token);

            logAction('ZERODHA_LOGIN_SUCCESS', {
                user_id: session.user_id,
                email: session.email
            });

            console.log('🎉 Zerodha authentication complete!\n');

            res.status(200).json({
                message: 'Successfully authenticated with Zerodha',
                user: session.user_id,
                expires_at: session.login_time // Token is valid for the day
            });
        } catch (error) {
            console.error(`❌ Zerodha callback error: ${error.message}`);
            logError(`Zerodha callback error: ${error.message}`);
            res.status(500).json({ error: `Authentication failed: ${error.message}` });
        }
    },

    /**
     * Get Check session status
     */
    checkSession: async (req, res) => {
        const isValid = await sessionManager.hasValidSession();
        console.log(`[Status Check] Is user authenticated? ${isValid ? 'YES ✅' : 'NO ❌'}`);
        res.status(200).json({ authenticated: isValid });
    }
};

module.exports = zerodhaController;
