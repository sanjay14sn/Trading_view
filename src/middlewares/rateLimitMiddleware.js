const rateLimit = require('express-rate-limit');

/**
 * Rate Limiting Middleware
 * Prevents DDoS and brute-force attacks on the webhook and dashboard endpoints.
 */
const webhookLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 30, // Limit each IP to 30 requests per windowMs
    message: {
        error: 'Too many requests from this IP, please try again after a minute'
    },
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

const apiLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per 15 mins for standard API
    skip: (req) => req.ip === '::1' || req.ip === '127.0.0.1', // Whitelist local for dev
    message: {
        error: 'Too many requests from this IP, please try again after 15 minutes'
    }
});

module.exports = { webhookLimiter, apiLimiter };
