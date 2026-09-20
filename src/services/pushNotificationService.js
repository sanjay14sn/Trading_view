const axios = require('axios');
const DeviceToken = require('../models/DeviceToken');
const { logError, logAction } = require('../utils/logger');
const config = require('../config');

/**
 * Push Notification Service
 * Sends FCM / WebPush high-priority alerts to mobile devices when signals arrive or trades update.
 * Works even when the mobile app is COLD, KILLED, or in BACKGROUND.
 */

// Global in-memory fallback list for quick access
const activeTokens = new Set();

const pushNotificationService = {
    /**
     * Register a new device token
     */
    async registerDeviceToken(tokenData) {
        if (!tokenData || !tokenData.token) {
            throw new Error('Push token is required');
        }

        activeTokens.add(tokenData.token);
        const record = await DeviceToken.registerToken(tokenData);
        logAction('PUSH_TOKEN_REGISTERED', { tokenPreview: tokenData.token.substring(0, 12) + '...' });
        return record;
    },

    /**
     * Get all registered push tokens
     */
    async getTokens() {
        try {
            const tokens = await DeviceToken.getAllTokens();
            tokens.forEach(t => activeTokens.add(t));
            return Array.from(activeTokens);
        } catch (err) {
            return Array.from(activeTokens);
        }
    },

    /**
     * Send high-priority push notification payload to all registered tokens
     */
    async sendSignalNotification(signal) {
        if (!signal) return;

        const tokens = await this.getTokens();
        const symbol = signal.symbol || signal.rawSymbol || 'NIFTY';
        const action = (signal.action || 'BUY').toUpperCase();
        const price = signal.price || 0;
        const title = `🚨 ${action} SIGNAL: ${symbol}`;
        const body = `Target Price: ₹${price} • Status: ${(signal.status || 'PENDING').toUpperCase()}`;

        const payload = {
            title,
            body,
            data: {
                type: 'SIGNAL_ALERT',
                symbol,
                action,
                price: String(price),
                signalId: String(signal._id || ''),
                receivedAt: String(signal.receivedAt || new Date().toISOString())
            },
            priority: 'high'
        };

        console.log(`📱 [PUSH NOTIFICATION] Sending signal alert for ${symbol} ${action} to ${tokens.length} devices...`);

        // If FCM server key is configured in env, send via FCM HTTP API
        const fcmServerKey = process.env.FCM_SERVER_KEY || config.fcmServerKey;

        if (fcmServerKey && tokens.length > 0) {
            await this._sendFcmHttp(fcmServerKey, tokens, payload);
        } else {
            console.log(`ℹ️ Push notification prepared (${tokens.length} token(s) registered). FCM Server Key not specified in env; notification logged & broadcast via WebSocket.`);
        }

        logAction('PUSH_SIGNAL_DISPATCHED', { symbol, action, tokensCount: tokens.length });
    },

    /**
     * Direct FCM Legacy / v1 HTTP dispatch helper
     */
    async _sendFcmHttp(serverKey, tokens, payload) {
        for (const token of tokens) {
            try {
                await axios.post(
                    'https://fcm.googleapis.com/fcm/send',
                    {
                        to: token,
                        priority: 'high',
                        notification: {
                            title: payload.title,
                            body: payload.body,
                            sound: 'default',
                            click_action: 'FLUTTER_NOTIFICATION_CLICK',
                            channel_id: 'tradingview_signals_channel'
                        },
                        data: payload.data
                    },
                    {
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': `key=${serverKey}`
                        },
                        timeout: 5000
                    }
                );
                console.log(`✅ FCM push sent to device token ${token.substring(0, 10)}...`);
            } catch (err) {
                const errDetail = err.response ? JSON.stringify(err.response.data) : err.message;
                logError(`FCM Push send failed for token ${token.substring(0, 10)}...: ${errDetail}`);
            }
        }
    }
};

module.exports = pushNotificationService;
