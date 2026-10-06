const { logAction, logError } = require('../utils/logger');
const tradeLifecycleManager = require('./tradeLifecycleManager');
const instrumentMapper = require('./instrumentMapper');
const socketService = require('./socketService');
const pushNotificationService = require('./pushNotificationService');
const config = require('../config');

/**
 * MT5 Order Manager Service
 * Queues orders for MT5 EA polling and processes execution results.
 * Supports OPEN, CLOSE, and atomic REVERSE orders for signal flipping.
 */
class MT5OrderManager {
    constructor() {
        this.pendingOrders = new Map();
        this.orderCounter = 0;
    }

    /**
     * Add a new OPEN order to MT5 pending queue (sl=0, tp=0)
     */
    async createOrder(tradeRecord, signalData = {}) {
        this.orderCounter++;
        const orderId = `ORD_MT5_${Date.now()}_${this.orderCounter}`;

        const rawSym = tradeRecord.symbol || signalData.symbol || config.mt5.symbol || 'BTC';
        const symbol = instrumentMapper.getFuturesSymbol(rawSym);
        const action = tradeRecord.action ? tradeRecord.action.toUpperCase() : 'BUY';
        let volume = tradeRecord.quantity || config.mt5.defaultLotSize || 1.0;
        if (symbol === 'BTC') volume = 1.0;
        const price = tradeRecord.entryPrice || signalData.price || 0;

        const pendingOrder = {
            orderId,
            tradeId: String(tradeRecord._id),
            type: 'OPEN', // OPEN, CLOSE, REVERSE
            symbol,
            action,
            volume,
            price,
            sl: signalData.sl || 0, // Default 0 for signal-only exit
            tp: signalData.target || signalData.tp || 0,
            magicNumber: config.mt5.magicNumber,
            createdAt: new Date().toISOString()
        };

        this.pendingOrders.set(orderId, pendingOrder);

        logAction('MT5_ORDER_QUEUED', {
            orderId,
            tradeId: pendingOrder.tradeId,
            type: 'OPEN',
            symbol,
            action,
            volume
        });

        return pendingOrder;
    }

    /**
     * Create an atomic REVERSE order to close existing opposite trade and open new trade
     */
    async createReverseOrder(newTradeRecord, existingTradeRecord, signalData = {}) {
        this.orderCounter++;

        const orderId = `REV_MT5_${Date.now()}_${this.orderCounter}`;

        const rawSym =
            newTradeRecord.symbol ||
            signalData.symbol ||
            config.mt5.symbol ||
            'BTC';

        const symbol = instrumentMapper.getFuturesSymbol(rawSym);

        const action = newTradeRecord.action
            ? newTradeRecord.action.toUpperCase()
            : 'BUY';

        let volume =
            newTradeRecord.quantity ||
            config.mt5.defaultLotSize ||
            1.0;

        if (symbol === 'BTC') {
            volume = 1.0;
        }

        const price =
            newTradeRecord.entryPrice ||
            signalData.price ||
            0;

        // ============================================================
        // IMPORTANT:
        // Remove every older pending order for this symbol.
        // Only the newest reversal is allowed to exist.
        // ============================================================

        for (const [oldOrderId, oldOrder] of this.pendingOrders.entries()) {

            const oldSymbol =
                instrumentMapper.getFuturesSymbol(
                    oldOrder.symbol || ''
                );

            if (oldSymbol === symbol) {

                console.log(
                    `🧹 Removing stale MT5 order: ${oldOrderId} | ${oldOrder.type} | ${oldOrder.action} | ${symbol}`
                );

                this.pendingOrders.delete(oldOrderId);
            }
        }

        const reverseOrder = {
            orderId,
            tradeId: String(newTradeRecord._id),
            closeTradeId: String(existingTradeRecord._id),
            closeTicket: existingTradeRecord.mt5Ticket || 0,
            type: 'REVERSE',
            symbol,
            action,
            volume,
            price,
            sl: signalData.sl || 0,
            tp: signalData.target || signalData.tp || 0,
            magicNumber: config.mt5.magicNumber,
            createdAt: new Date().toISOString()
        };

        this.pendingOrders.set(orderId, reverseOrder);

        logAction('MT5_REVERSE_ORDER_QUEUED', {
            orderId,
            newTradeId: reverseOrder.tradeId,
            closeTradeId: reverseOrder.closeTradeId,
            closeTicket: reverseOrder.closeTicket,
            symbol,
            action,
            volume
        });

        return reverseOrder;
    }

    /**
     * Retrieve all pending orders for EA polling request
     */
    getPendingOrders() {
        const orders = Array.from(this.pendingOrders.values());

        console.log('==========================================');
        console.log('📡 MT5 PENDING ORDER POLL');
        console.log('📦 Total orders in memory:', orders.length);

        orders.forEach(order => {
            console.log(
                `➡️ ${order.orderId} | ${order.type} | ${order.action} | ${order.symbol} | Trade: ${order.tradeId}`
            );
        });

        const bySymbol = new Map();

        for (const order of orders) {
            const symbol = order.symbol || 'BTCUSD';

            if (!bySymbol.has(symbol)) {
                bySymbol.set(symbol, []);
            }

            bySymbol.get(symbol).push(order);
        }

        const result = [];

        for (const [symbol, symbolOrders] of bySymbol.entries()) {

            const reverseOrders = symbolOrders.filter(
                order => order.type === 'REVERSE'
            );

            if (reverseOrders.length > 0) {

                reverseOrders.sort(
                    (a, b) =>
                        new Date(b.createdAt) -
                        new Date(a.createdAt)
                );

                result.push(reverseOrders[0]);

                console.log(
                    `🔄 RETURNING REVERSE: ${reverseOrders[0].orderId} | ${reverseOrders[0].action} | ${symbol}`
                );

                continue;
            }

            symbolOrders.sort(
                (a, b) =>
                    new Date(b.createdAt) -
                    new Date(a.createdAt)
            );

            result.push(symbolOrders[0]);

            console.log(
                `📤 RETURNING OPEN: ${symbolOrders[0].orderId} | ${symbolOrders[0].action} | ${symbol}`
            );
        }

        console.log('📤 Orders returned to MT5:', result.length);
        console.log('==========================================');

        return result;
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

            // Broadcast real-time socket event for mobile app & web dashboard
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
