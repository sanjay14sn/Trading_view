require('dotenv').config();
const notificationService = require('./src/services/notificationService');

async function testTelegram() {
    console.log('Testing Telegram Integration...');
    try {
        await notificationService.sendTelegram("🧪 Hello! This is a test message to verify that Telegram integration is working correctly.");
        console.log('✅ Test message sent. Please check your Telegram app!');
    } catch (error) {
        console.error('❌ Failed to send message:', error);
    }
}

testTelegram();
