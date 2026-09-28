require('dotenv').config();

const config = {
    env: process.env.NODE_ENV || 'development',
    port: parseInt(process.env.PORT, 10) || 3000,
    webhookSecret: process.env.WEBHOOK_SECRET,
    takePositions: process.env.TAKE_POSITIONS !== 'false',

    mongodb: {
        uri: process.env.MONGO_URI || 'mongodb://localhost:27017/tradingview_prod'
    },

    redis: {
        url: process.env.REDIS_URL || 'redis://localhost:6379'
    },

    mt5: {
        symbol: process.env.MT5_SYMBOL || 'BTCUSD',
        magicNumber: parseInt(process.env.MT5_MAGIC_NUMBER, 10) || 123456,
        eaToken: process.env.MT5_EA_TOKEN || 'hantec_mt5_secret',
        defaultLotSize: parseFloat(process.env.MT5_DEFAULT_LOT) || 0.01
    },

    risk: {
        maxTradesPerDay: parseInt(process.env.MAX_TRADES_PER_DAY, 10) || 10,
        maxDailyLoss: parseInt(process.env.MAX_DAILY_LOSS_INR, 10) || 5000,
        tradeCooldownMs: parseInt(process.env.TRADE_COOLDOWN_MS, 10) || 30000
    },

    telegram: {
        botToken: process.env.TELEGRAM_BOT_TOKEN,
        chatId: process.env.TELEGRAM_CHAT_ID
    }
};

// Simple validation
const requiredKeys = [
    'webhookSecret'
];

if (config.env === 'production') {
    // In production, enforce these
    // For now, just log warnings if missing
    requiredKeys.forEach(key => {
        const value = key.split('.').reduce((obj, i) => obj?.[i], config);
        if (!value) {
            console.warn(`⚠️  Missing required config: ${key}`);
        }
    });
}

module.exports = config;
