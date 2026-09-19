const crypto = require('crypto');
require('dotenv').config();

/**
 * 🔐 TradingView Signature Generator
 * Use this utility to generate valid HMAC-SHA256 signatures for your signals.
 */

// 1. Get Secret from .env
const secret = process.env.WEBHOOK_SECRET;

if (!secret || secret === 'your_webhook_secret_here') {
    console.error('❌ ERROR: Please set a valid WEBHOOK_SECRET in your .env file first.');
    process.exit(1);
}

// 2. Define the exact payload you want to send
const payload = {
    symbol: "NIFTY",
    action: "SELL",
    price: 24500.50,
    passphrase: "your_top_secret_passphrase"
};

const stringify = require('json-stable-stringify');

// 3. Generate HMAC-SHA256 Signature (Stable for reliable verification)
const signature = crypto
    .createHmac('sha256', secret)
    .update(stringify(payload))
    .digest('hex');

console.log('\n--- 🛡️  TradingView Signal Test Utility ---');
console.log('Payload:', JSON.stringify(payload, null, 2));
console.log('------------------------------------------');
console.log('✅ Signature:', signature);
console.log('------------------------------------------');
console.log('\n🚀 Use this curl command to test:');
console.log(`
curl -X POST http://localhost:3000/tradingview-signal \\
  -H "Content-Type: application/json" \\
  -H "X-TradingView-Signature: ${signature}" \\
  -d '${stringify(payload)}'
`);
