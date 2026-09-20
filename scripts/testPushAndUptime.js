require('dotenv').config();
const pushNotificationService = require('../src/services/pushNotificationService');
const keepAliveService = require('../src/services/keepAliveService');

async function testPushAndUptime() {
    console.log('🧪 Starting Push Notification & Uptime Verification Test...\n');

    try {
        // 1. Test Device Token Registration
        console.log('1️⃣ Registering test mobile device push token...');
        const tokenResult = await pushNotificationService.registerDeviceToken({
            token: 'test_fcm_token_device_abc123',
            platform: 'android',
            deviceId: 'test_pixel_7'
        });
        console.log('   ✅ Push Token Registered:', tokenResult.token || tokenResult);

        // 2. Test Push Notification Dispatch for Cold State Signal
        console.log('\n2️⃣ Testing Push Notification dispatch for incoming signal...');
        await pushNotificationService.sendSignalNotification({
            _id: 'test_signal_999',
            symbol: 'NIFTY26SEPFUT',
            rawSymbol: 'NIFTY',
            action: 'BUY',
            price: 25420.50,
            status: 'accepted',
            receivedAt: new Date().toISOString()
        });
        console.log('   ✅ Push Signal Dispatch test completed successfully!');

        // 3. Test Keep-Alive Service Initialization
        console.log('\n3️⃣ Testing Keep-Alive Watchdog Service...');
        keepAliveService.start();
        console.log('   ✅ Keep-Alive Service started cleanly.');
        keepAliveService.stop();

        console.log('\n🎉 ALL VERIFICATION TESTS PASSED SUCCESSFULLY!');
    } catch (err) {
        console.error('❌ Verification test failed:', err);
        process.exit(1);
    }
}

testPushAndUptime();
