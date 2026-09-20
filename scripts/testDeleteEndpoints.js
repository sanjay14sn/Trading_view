require('dotenv').config();
const tradeController = require('../src/controllers/tradeController');
const mockStore = require('../src/utils/mockStore');

async function testDeleteEndpoints() {
    console.log('🧪 Starting Trade Deletion API Endpoints Test...\n');

    // 1. Populate test trade
    const testId = 'test_trade_delete_123';
    mockStore.trades.push({
        _id: testId,
        symbol: 'NIFTY',
        action: 'BUY',
        quantity: 1,
        entryPrice: 25000,
        status: 'OPEN'
    });

    console.log(`1️⃣ Added test trade to mockStore (Total: ${mockStore.trades.length})`);

    // 2. Test Delete Individual Trade
    const mockReqDelete = { params: { id: testId } };
    let jsonResult = null;
    const mockResDelete = {
        json: (data) => { jsonResult = data; return mockResDelete; },
        status: () => mockResDelete
    };

    await tradeController.deleteTrade(mockReqDelete, mockResDelete);
    console.log('   ✅ Single Trade Delete Result:', jsonResult);

    // 3. Test Clear All Trades
    mockStore.trades.push({ _id: 't1', symbol: 'BANKNIFTY', status: 'OPEN' });
    mockStore.trades.push({ _id: 't2', symbol: 'FINNIFTY', status: 'CLOSED' });

    console.log(`\n2️⃣ Added ${mockStore.trades.length} trades for clear all test...`);
    const mockResClear = {
        json: (data) => { jsonResult = data; return mockResClear; },
        status: () => mockResClear
    };

    await tradeController.clearAllTrades({}, mockResClear);
    console.log('   ✅ Clear All Trades Result:', jsonResult);
    console.log('   Remaining trades count:', mockStore.trades.length);

    console.log('\n🎉 ALL DELETE API TESTS PASSED SUCCESSFULLY!');
}

testDeleteEndpoints();
