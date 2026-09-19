const http = require('http');
const app = require('./src/app');
const connectDB = require('./src/db/mongoose');
const socketService = require('./src/services/socketService');
const setupZerodhaWorker = require('./src/queues/workers/zerodhaWorker');
const setupCronJobs = require('./src/utils/cronJobs');
const slWatcher = require('./src/services/slWatcherService');
const config = require('./src/config');
const { logError } = require('./src/utils/logger');

const PORT = config.port;
const server = http.createServer(app);

// 1. Connect to MongoDB
connectDB();

// 2. Initialize WebSocket & Set on App
const io = socketService.init(server);
app.set('io', io);

// 3. Initialize Background Workers (BullMQ)
setupZerodhaWorker(io);

// 4. Initialize Cron Jobs
setupCronJobs();

// 5. Start SL/TP Monitoring Service
slWatcher.start(io);

// 🚀 Start the server
server.listen(PORT, () => {
    console.log(`\n✅ TradingView Backend (${config.env}) is now LIVE`);
    console.log(`🌐 http://localhost:${PORT}`);
    console.log(`📡 Webhook: http://localhost:${PORT}/tradingview-signal`);
    console.log(`👁️  SL Watcher active\n`);
});

// 🔴 Handle system-level errors
process.on('unhandledRejection', (err) => {
    console.error('🔴 FATAL: Unhandled Rejection');
    logError(err);
    server.close(() => process.exit(1));
});

process.on('uncaughtException', (err) => {
    console.error('🔴 FATAL: Uncaught Exception');
    logError(err);
    server.close(() => process.exit(1));
});
