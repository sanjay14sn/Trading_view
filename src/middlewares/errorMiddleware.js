const { logError } = require('../utils/logger');
const config = require('../config');

/**
 * Global Error Handling Middleware
 * Catch-all for any unhandled errors in the request-response cycle.
 */
const errorHandler = (err, req, res, next) => {
    const statusCode = err.statusCode || 500;

    // Log the error
    logError(err, {
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
        statusCode
    });

    // Send response
    res.status(statusCode).json({
        status: 'error',
        message: config.env === 'production'
            ? 'An internal server error occurred'
            : err.message,
        ...(config.env === 'development' && { stack: err.stack })
    });
};

module.exports = errorHandler;
