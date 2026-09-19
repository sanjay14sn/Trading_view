const axios = require('axios');
const config = require('../config');
const { logError, logAction } = require('../utils/logger');

/**
 * Notification Service
 * Sends alerts to Telegram for fills, SL hits, and system errors.
 */
const notificationService = {
    async sendTelegram(message) {
        if (!config.telegram.botToken || !config.telegram.chatId) {
            return;
        }

        try {
            const url = `https://api.telegram.org/bot${config.telegram.botToken}/sendMessage`;
            await axios.post(url, {
                chat_id: config.telegram.chatId,
                text: `<b>🔔 TV ALGO ALERT</b>\n\n${message}`,
                parse_mode: 'HTML'
            });
            logAction('TELEGRAM_SENT', { preview: message.substring(0, 50) + '...' });
        } catch (error) {
            const errorMsg = error.response ? JSON.stringify(error.response.data) : error.message;
            logError(`Telegram alert failed: ${errorMsg}`);
        }
    },

    async notifySignalReceived(signal) {
        if (!signal) return;
        const msg = `🎯 <b>SIGNAL RECEIVED</b>\n\n<b>Symbol:</b> ${signal.symbol}\n<b>Action:</b> ${signal.action}\n<b>Price:</b> ₹${signal.price}\n<b>Status:</b> ${signal.status}`;
        await this.sendTelegram(msg);
    },

    async notifyTradeOpen(trade) {
        if (!trade) return;
        const msg = `✅ <b>TRADE OPENED</b>\n\n<b>Symbol:</b> ${trade.symbol}\n<b>Action:</b> ${trade.action}\n<b>Price:</b> ${trade.entryPrice}\n<b>Qty:</b> ${trade.quantity}`;
        await this.sendTelegram(msg);
    },

    async notifyTradeClose(trade, reason) {
        if (!trade) return;
        const pnlIcon = (trade.pnl || 0) >= 0 ? '💰' : '📉';
        const msg = `${pnlIcon} <b>TRADE CLOSED (${reason})</b>\n\n<b>Symbol:</b> ${trade.symbol}\n<b>Exit Price:</b> ${trade.exitPrice}\n<b>P&L:</b> ₹${trade.pnl || 0}`;
        await this.sendTelegram(msg);
    },

    async notifyRiskAlert(reason, stats) {
        const msg = `⚠️ <b>RISK ALERT</b>\n\n<b>Reason:</b> ${reason}\n<b>Stats:</b> ${JSON.stringify(stats)}`;
        await this.sendTelegram(msg);
    }
};

module.exports = notificationService;
