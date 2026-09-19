const { Worker } = require('bullmq');
const redis = require('../../utils/redis');
const zerodhaEngine = require('../../services/zerodhaExecutionEngine');
const tradeLifecycle = require('../../services/tradeLifecycleManager');
const { logError, logOrder, logAction } = require('../../utils/logger');

/**
 * Zerodha Worker
 * Processes background order execution tasks from BullMQ.
 */
const setupZerodhaWorker = (io) => {
    // 🛡️ Skip if in mock mode (no real Redis or Broker)
    if (redis.isMock) {
        console.warn('⚠️  Zerodha worker skipped (Mock Mode). Orders will be simulated in-memory.');
        return null;
    }

    const worker = new Worker('orders', async (job) => {
        const { signalData, tradeId } = job.data;
        console.log(`⚙️  Processing order for trade ${tradeId} (${signalData.symbol})`);

        try {
            // 1. Update Trade status to QUEUED
            await tradeLifecycle.updateTrade(tradeId, { status: 'QUEUED' });

            // 2. Place order via Zerodha (with dev fallback if API token not active)
            let kiteOrderId = `mock_order_${Date.now()}`;
            try {
                kiteOrderId = await zerodhaEngine.placeOrder(signalData);
            } catch (err) {
                if (process.env.NODE_ENV === 'development') {
                    console.warn(`⚠️  Zerodha API order placement skipped (${err.message}). Simulating placement in dev mode.`);
                } else {
                    throw err;
                }
            }

            // 3. Update Trade status to OPEN
            const trade = await tradeLifecycle.updateTrade(tradeId, {
                status: 'OPEN',
                kiteOrderId
            });

            // Notify Trade Open (Telegram + Voice Call)
            const notificationService = require('../../services/notificationService');
            await notificationService.notifyTradeOpen(trade);

            // 4. Broadcast via WebSocket
            if (io) {
                io.emit('order_placed', {
                    tradeId,
                    symbol: signalData.symbol,
                    kiteOrderId,
                    receivedAt: new Date().toISOString()
                });
            }

            logOrder('filled', {
                symbol: signalData.symbol,
                kiteOrderId,
                tradeId
            });

            return { kiteOrderId };
        } catch (error) {
            logError(`Worker failed to place order: ${error.message}`, { tradeId, job: job.id });

            // On failure, update trade status if it's the last attempt
            if (job.attemptsMade >= 2) { // 0, 1, 2 = 3 attempts total
                await tradeLifecycle.updateTrade(tradeId, { status: 'FAILED' });
                logAction('ORDER_FAILED_FINAL', { tradeId, error: error.message });
            }

            throw error; // Rethrow to trigger BullMQ retry
        }
    }, { connection: redis });

    worker.on('completed', (job) => {
        console.log(`✅ Order job ${job.id} completed`);
    });

    worker.on('failed', (job, err) => {
        logError(`❌ Order job ${job.id} failed: ${err.message}`, { jobId: job.id });
    });

    console.log('🤖 Zerodha worker initialized');
    return worker;
};

module.exports = setupZerodhaWorker;
