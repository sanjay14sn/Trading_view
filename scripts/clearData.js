const mongoose = require('mongoose');
const config = require('../src/config');
const Signal = require('../src/models/Signal');
const Trade = require('../src/models/Trade');
const AuditLog = require('../src/models/AuditLog');
const PnlDaily = require('../src/models/PnlDaily');

async function clearData() {
    try {
        console.log('🔗 Connecting to MongoDB...');
        await mongoose.connect(config.mongodb.uri);
        console.log('✅ Connected to MongoDB.');

        const collections = [
            { name: 'Signals', model: Signal },
            { name: 'Trades', model: Trade },
            { name: 'AuditLogs', model: AuditLog },
            { name: 'PnlDailies', model: PnlDaily }
        ];

        for (const { name, model } of collections) {
            const result = await model.deleteMany({});
            console.log(`🗑️  Cleared ${name}: Deleted ${result.deletedCount} documents.`);
        }

        console.log('✨ Data cleanup complete.');
    } catch (error) {
        console.error('❌ Error clearing data:', error.message);
    } finally {
        await mongoose.disconnect();
        console.log('🔌 Disconnected from MongoDB.');
        process.exit(0);
    }
}

clearData();
