const winston = require('winston');
const path = require('path');
const config = require('../config');

// Custom format for human-readability in console during dev
const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.printf(({ timestamp, level, message, ...metadata }) => {
        let msg = `${timestamp} [${level}]: ${message}`;
        if (Object.keys(metadata).length > 0 && metadata.label !== 'signal' && metadata.label !== 'order') {
            msg += ` ${JSON.stringify(metadata)}`;
        }
        return msg;
    })
);

// JSON format for production logs
const jsonFormat = winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
);

const logger = winston.createLogger({
    level: config.env === 'production' ? 'info' : 'debug',
    format: jsonFormat,
    defaultMeta: { service: 'tradingview-service' },
    transports: [
        // Standard Console
        new winston.transports.Console({
            format: config.env === 'production' ? jsonFormat : consoleFormat
        }),
        // Combined file
        new winston.transports.File({
            filename: path.join('logs', 'combined.log'),
            maxsize: 5242880, // 5MB
            maxFiles: 5
        }),
        // Separate Error file
        new winston.transports.File({
            filename: path.join('logs', 'errors.log'),
            level: 'error',
            maxsize: 5242880,
            maxFiles: 5
        })
    ]
});

// Production helpers
const logSignal = (signal, status = 'accepted', reason = null) => {
    logger.info(`SIGNAL_RECEIVED: ${signal.symbol}`, {
        label: 'signal',
        symbol: signal.symbol,
        action: signal.action,
        price: signal.price,
        status,
        reason
    });
};

const logOrder = (action, details) => {
    logger.info(`ORDER_${action.toUpperCase()}: ${details.symbol}`, {
        label: 'order',
        ...details
    });
};

const logError = (error, context = {}) => {
    const message = error instanceof Error ? error.message : error;
    const stack = error instanceof Error ? error.stack : null;
    logger.error(message, { ...context, stack });
};

// For the AuditLog service
const logAction = (action, payload, actor = 'system') => {
    logger.info(`ACTION: ${action}`, { action, payload, actor });
};

module.exports = {
    logger,
    logSignal,
    logOrder,
    logError,
    logAction
};
