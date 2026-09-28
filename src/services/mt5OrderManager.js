const { logAction, logError } = require('../utils/logger');
const tradeLifecycleManager = require('./tradeLifecycleManager');
const socketService = require('./socketService');
const pushNotificationService = require('./pushNotificationService');
const config = require('../config');

/**
 * MT5 Order Manager Service
 * Queues orders for MT5 EA polling and processes execution results.
 */
class MT5OrderManager {
    constructor() {
        // Pending order queue for EA polling
        this.pendingOrders = new Map();
        this.orderCounter = 0;
    }

    /**
     * Add a new signal trade to MT5 pending order queue
     */
    async createOrder(tradeRecord, signalData = {}) {
        this.orderCounter++;
        const orderId = `ORD_MT5_${Date.now()}_${this.orderCounter}`;

        const symbol = tradeRecord.symbol || config.mt5.symbol || 'BTCUSD';
        const action = tradeRecord.action ? tradeRecord.action.toUpperCase() : 'BUY';
        const volume = tradeRecord.quantity || config.mt5.defaultLotSize || 0.01;
        const price = tradeRecord.entryPrice || signalData.price || 0;

        const pendingOrder = {
            orderId,
            tradeId: String(tradeRecord._id),
            type: 'OPEN', // OPEN or CLOSE
            symbol,
            action,
            volume,
            price,
            sl: tradeRecord.sl || signalData.sl || 0,
            tp: tradeRecord.target || signalData.target || 0,
            magicNumber: config.mt5.magicNumber,
            createdAt: new Date().toISOString()
        };

        this.pendingOrders.set(orderId, pendingOrder);

        logAction('MT5_ORDER_QUEUED', {
            orderId,
            tradeId: pendingOrder.tradeId,
            symbol,
            action,
            volume
        });

        return pendingOrder;
    }

    /**
     * Retrieve all pending orders for EA polling request
     */
    getPendingOrders() {
        return Array.from(this.pendingOrders.values());
    }

    /**
     * Handle execution confirmation posted back from MT5 EA
     */
    async handleExecutionResult(result = {}) {
        const { orderId, tradeId, ticket, fillPrice, status, comment, rejectionReason } = result;

        logAction('MT5_EXECUTION_RESULT', {
            orderId,
            tradeId,
            ticket,
            fillPrice,
            status,
            rejectionReason
        });

        // 1. Remove from pending queue
        if (orderId && this.pendingOrders.has(orderId)) {
            this.pendingOrders.delete(orderId);
        }

        // 2. Process filled order
        if (status === 'FILLED' || status === 'SUCCESS') {
            const updates = {
                status: 'OPEN',
                entryPrice: parseFloat(fillPrice) || 0,
                mt5Ticket: parseInt(ticket, 10) || 0,
                mt5MagicNumber: config.mt5.magicNumber
            };

            const updatedTrade = await tradeLifecycleManager.updateTrade(tradeId, updates);

            // 3. Emit real-time socket event for mobile app & web dashboard
            socketService.emitEvent('order_placed', {
                tradeId,
                symbol: updatedTrade.symbol,
                action: updatedTrade.action,
                fillPrice: updatedTrade.entryPrice,
                ticket: updatedTrade.mt5Ticket,
                status: 'OPEN'
            });

            return updatedTrade;
        } else {
            // Order failed or rejected by MT5 broker
            const updates = {
                status: 'FAILED',
                rejectionReason: rejectionReason || comment || 'MT5 Execution Rejected'
            };
            const updatedTrade = await tradeLifecycleManager.updateTrade(tradeId, updates);

            socketService.emitEvent('order_failed', {
                tradeId,
                reason: updates.rejectionReason
            });

            return updatedTrade;
        }
    }
}

module.exports = new MT5OrderManager();
