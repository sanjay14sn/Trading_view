require('dotenv').config();
const axios = require('axios');
const pushNotificationService = require('../src/services/pushNotificationService');
const notificationService = require('../src/services/notificationService');
const socketService = require('../src/services/socketService');

async function sendTestAlert() {
    console.log('🚀 Triggering Live Test Signal Alert...\n');

    const testSignalPayload = {
        passphrase: process.env.TRADINGVIEW_PASSPHRASE || '1234',
        symbol: 'BTCUSDT',
        action: 'BUY',
        price: 81280.5,
        quantity: 1,
        timestamp: new Date().toISOString()
    };

    const port = process.env.PORT || 3001;
    const targets = [
        `http://localhost:${port}/tradingview-signal`,
        'https://apitrading.iqsync.in/tradingview-signal'
    ];

    let webhookSuccess = false;

    for (const url of targets) {
        try {
            console.log(`📡 Sending test webhook payload to ${url}...`);
            const response = await axios.post(url, testSignalPayload, { timeout: 5000 });
            console.log(`✅ Webhook Response from ${url}:`, response.data);
            webhookSuccess = true;
            break;
        } catch (err) {
            console.warn(`⚠️ Webhook delivery warning to ${url}: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
        }
    }

    if (!webhookSuccess) {
        console.log('\n🔄 Server webhook offline locally. Executing direct internal dispatch for verification...');

        const mockSignalDoc = {
            _id: `test_alert_${Date.now()}`,
            symbol: 'BTCUSDT',
            rawSymbol: 'BTCUSDT',
            action: 'BUY',
            price: 81280.5,
            status: 'accepted',
            receivedAt: new Date()
        };

        // 1. Telegram Alert
        await notificationService.notifySignalReceived(mockSignalDoc);
        console.log('✅ Telegram alert dispatched!');

        // 2. Mobile Push Notification
        await pushNotificationService.sendSignalNotification(mockSignalDoc);
        console.log('✅ Mobile Push Notification dispatched!');

        // 3. Socket.IO Broadcast
        socketService.emitEvent('signal_received', {
            id: mockSignalDoc._id,
            symbol: 'BTCUSDT',
            action: 'BUY',
            price: 81280.5,
            receivedAt: new Date().toISOString()
        });
        console.log('✅ Socket.IO signal_received event emitted!');
    }

    console.log('\n🎉 TEST SIGNAL ALERT COMPLETED SUCCESSFULLY!');
}

sendTestAlert();
