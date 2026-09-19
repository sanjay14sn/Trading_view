const { Queue } = require('bullmq');
const redis = require('../utils/redis');
const { logError } = require('../utils/logger');

/**
 * Order Queue for Zerodha execution
 * Decouples weaponized signal receipt from execution for reliability.
 */
let orderQueue;

// Only initialize BullMQ if not in mock mode or if redis is real
if (redis.isMock) {
    console.warn('⚠️  Redis Mock active. Skipping BullMQ initialization.');
    orderQueue = {
        add: async () => console.log('📦 [MOCK QUEUE] Order processed instantly in-memory.')
    };
} else {
    orderQueue = new Queue('orders', { connection: redis });
}

const addOrderToQueue = async (signalData, tradeId) => {
    try {
        if (redis.isMock) {
            console.log(`📬 [MOCK] Order for ${signalData.symbol} simulated`);
            return;
        }

        await orderQueue.add('place-order', { signalData, tradeId }, {
            attempts: 3,
            backoff: {
                type: 'exponential',
                delay: 2000,
            },
            removeOnComplete: true,
            removeOnFail: false
        });
        console.log(`📬 Order for ${signalData.symbol} added to queue`);
    } catch (error) {
        logError(`Failed to add order to queue: ${error.message}`);
        // In dev, we can swallow this to avoid breaking the whole signal pipe
        if (process.env.NODE_ENV !== 'production') {
            console.warn('⚠️  Non-fatal queue failure in development.');
            return;
        }
        throw error;
    }
};

module.exports = { orderQueue, addOrderToQueue };
