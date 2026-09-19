const crypto = require('crypto');
const config = require('../config');
const { logError } = require('../utils/logger');

/**
 * HMAC Authentication Middleware
 * Verifies that the request is coming from TradingView using a shared secret.
 * TradingView must be configured to send the 'X-TradingView-Signature' header.
 */
const verifyWebhook = (req, res, next) => {
    try {
        const secret = config.webhookSecret;
        const passphrase = process.env.TRADINGVIEW_PASSPHRASE;
        const providedSignature = req.headers['x-tradingview-signature'];
        const providedPassphrase = req.body?.passphrase;

        // 🛡️ Priority 1: Simple Passphrase (Recommended for Direct TradingView Integration)
        if (passphrase && providedPassphrase === passphrase) {
            return next();
        }

        // 🛡️ Priority 2: HMAC Signature (Advanced)
        if (secret && providedSignature) {
            const stringify = require('json-stable-stringify');
            const hmac = crypto.createHmac('sha256', secret);
            const body = stringify(req.body);
            const expectedSignature = hmac.update(body).digest('hex');

            if (providedSignature === expectedSignature) {
                return next();
            }
        }

        // ⚠️ Fallback for Local Dev (Danger: No Security)
        if (!secret && !passphrase) {
            console.warn('⚠️ No security configured. Skipping verification.');
            return next();
        }

        logError('Unauthorized webhook attempt', {
            ip: req.ip,
            hasSignature: !!providedSignature,
            hasPassphrase: !!providedPassphrase
        });

        return res.status(401).json({ error: 'Unauthorized: Invalid Passphrase or Signature' });

    } catch (error) {
        logError(`Auth middleware error: ${error.message}`);
        res.status(500).json({ error: 'Internal Auth Error' });
    }
};

module.exports = { verifyWebhook };
