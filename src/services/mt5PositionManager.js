const tradeLifecycleManager = require('./tradeLifecycleManager');
const mt5OrderManager = require('./mt5OrderManager');
const instrumentMapper = require('./instrumentMapper');
const socketService = require('./socketService');
const pushNotificationService = require('./pushNotificationService');
const pnlService = require('./pnlService');
const { logAction, logError } = require('../utils/logger');
const config = require('../config');

/**
 * MT5 Position Manager Service
 * Manages open MT5 positions, manual closure requests, and close confirmations from EA.
 */
class MT5PositionManager {
    /**
     * Initiate a manual or automated position close command for MT5 EA
     */
    async requestClosePosition(tradeId, reason = 'MANUAL_EXIT') {
        const trade = await tradeLifecycleManager.updateTrade(tradeId, {});
        if (!trade || trade.status !== 'OPEN') {
            throw new Error(`Trade ${tradeId} is not in OPEN status or does not exist`);
        }

        const ticket = trade.mt5Ticket;
        const rawSym = trade.symbol || config.mt5.symbol || 'BTC';
        const symbol = instrumentMapper.getFuturesSymbol(rawSym);

        // Add CLOSE order command to pending queue for EA
        mt5OrderManager.orderCounter++;
        const orderId = `CLOSE_MT5_${Date.now()}_${mt5OrderManager.orderCounter}`;

        const closeOrder = {
            orderId,
            tradeId: String(trade._id),
            ticket: ticket || 0,
            type: 'CLOSE', // Close position
            symbol,
            action: trade.action.toUpperCase() === 'BUY' ? 'SELL' : 'BUY', // Inverse deal
            volume: symbol === 'BTC' ? 1.0 : (trade.quantity || config.mt5.defaultLotSize || 1.0),
            magicNumber: config.mt5.magicNumber,
            reason,
            createdAt: new Date().toISOString()
        };

        mt5OrderManager.pendingOrders.set(orderId, closeOrder);

        logAction('MT5_POSITION_CLOSE_REQUESTED', {
            tradeId,
            ticket,
            symbol,
            reason
        });

        return closeOrder;
    }

    /**
     * Handle position close confirmation reported by MT5 EA
     */
    async handleTradeClosed(closeData = {}) {
        const { tradeId, ticket, exitPrice, pnl, reason = 'CLOSED' } = closeData;

        logAction('MT5_TRADE_CLOSED_RECEIVED', {
            tradeId,
            ticket,
            exitPrice,
            pnl,
            reason
        });

        let targetTradeId = tradeId;

        // If tradeId not sent directly, find trade by mt5Ticket
        if (!targetTradeId && ticket) {
            const Trade = require('../models/Trade');
            const tradeDoc = await Trade.findOne({ mt5Ticket: parseInt(ticket, 10), status: 'OPEN' });
            if (tradeDoc) {
                targetTradeId = String(tradeDoc._id);
            }
        }

        if (!targetTradeId) {
            logError(`Received trade close for ticket ${ticket} but no matching open trade was found.`);
            return null;
        }

        const parsedExitPrice = parseFloat(exitPrice) || 0;

        // Finalize trade state via tradeLifecycleManager
        const closedTrade = await tradeLifecycleManager.closeTrade(targetTradeId, parsedExitPrice, reason);

        // Override/re-verify calculated PnL if EA reported exact broker PnL
        if (typeof pnl !== 'undefined' && pnl !== null) {
            closedTrade.pnl = parseFloat(pnl);
            await closedTrade.save?.();
        }

        // Update daily PnL aggregator
        try {
            await pnlService.updateDailyPnl(closedTrade);
        } catch (err) {
            logError(`Failed to update daily PnL: ${err.message}`);
        }

        // Broadcast real-time WebSocket event
        socketService.emitEvent('trade_closed', {
            tradeId: closedTrade._id,
            symbol: closedTrade.symbol,
            exitPrice: closedTrade.exitPrice,
            pnl: closedTrade.pnl,
            reason: closedTrade.status
        });

        // Send Push Notification alert to Flutter app
        pushNotificationService.sendSignalNotification({
            symbol: closedTrade.symbol,
            action: `CLOSED (${closedTrade.status})`,
            price: closedTrade.exitPrice,
            status: closedTrade.pnl >= 0 ? `PROFIT: +$${closedTrade.pnl}` : `LOSS: -$${Math.abs(closedTrade.pnl)}`
        }).catch(err => logError(`Push notification warning: ${err.message}`));

        return closedTrade;
    }
}

module.exports = new MT5PositionManager();
