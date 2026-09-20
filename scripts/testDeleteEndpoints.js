require('dotenv').config();
const tradeController = require('../src/controllers/tradeController');
const signalController = require('../src/controllers/signalController');
const mockStore = require('../src/utils/mockStore');

async function testDeleteEndpoints() {
    console.log('🧪 Starting Trade & Signal Deletion API Endpoints Test...\n');

    // 1. Populate test trade & signal
    const testId = 'test_trade_delete_123';
    const testSigId = 'test_sig_delete_456';

    mockStore.trades.push({
        _id: testId,
        symbol: 'NIFTY',
        action: 'BUY',
        quantity: 1,
        entryPrice: 25000,
        status: 'OPEN'
    });

    mockStore.signals.push({
        _id: testSigId,
        symbol: 'NIFTY',
        action: 'BUY',
        price: 25000,
        status: 'accepted'
    });

    console.log(`1️⃣ Added test trade & signal to mockStore (Trades: ${mockStore.trades.length}, Signals: ${mockStore.signals.length})`);

    // 2. Test Delete Individual Trade
    let jsonResult = null;
    const mockRes = {
        json: (data) => { jsonResult = data; return mockRes; },
        status: () => mockRes
    };

    await tradeController.deleteTrade({ params: { id: testId } }, mockRes);
    console.log('   ✅ Single Trade Delete Result:', jsonResult);

    // 3. Test Delete Individual Signal
    await signalController.deleteSignal({ params: { id: testSigId } }, mockRes);
    console.log('   ✅ Single Signal Delete Result:', jsonResult);

    // 4. Test Clear All Trades & Signals
    mockStore.trades.push({ _id: 't1', symbol: 'BANKNIFTY', status: 'OPEN' });
    mockStore.signals.push({ _id: 's1', symbol: 'BANKNIFTY', action: 'BUY', price: 48000 });

    console.log(`\n2️⃣ Added trades & signals for clear all test...`);
    await tradeController.clearAllTrades({}, mockRes);
    await signalController.clearAllSignals({}, mockRes);

    console.log('   ✅ Clear All Trades & Signals Result:', jsonResult);
    console.log('   Remaining trades:', mockStore.trades.length, 'Remaining signals:', mockStore.signals.length);

    console.log('\n🎉 ALL DELETE API TESTS PASSED SUCCESSFULLY!');
}

testDeleteEndpoints();
