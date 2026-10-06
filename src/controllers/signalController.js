const mongoose = require('mongoose');
const Signal = require('../models/Signal');
const Trade = require('../models/Trade');
const deduplication = require('../services/deduplicationService');
const marketHours = require('../services/marketHoursService');
const riskManager = require('../services/riskManager');
const tradeLifecycle = require('../services/tradeLifecycleManager');
const { addOrderToQueue } = require('../queues/orderQueue');
const instrumentMapper = require('../services/instrumentMapper');
const socketService = require('../services/socketService');
const notificationService = require('../services/notificationService');
const pushNotificationService = require('../services/pushNotificationService');
const { logSignal, logError, logAction } = require('../utils/logger');
const config = require('../config');
const mockStore = require('../utils/mockStore');

const isDbConnected = () => mongoose.connection.readyState === 1;

/**
 * Signal Controller
 * The heart of the trading engine processing incoming TradingView webhooks.
 */
const postSignal = async (req, res) => {
    try {
        const rawSignal = req.body || {};
        const symbolInput = rawSignal.symbol ? String(rawSignal.symbol) : 'NIFTY';
        const actionInput = rawSignal.action ? String(rawSignal.action).toUpperCase() : 'BUY';
        const priceInput = rawSignal.price ? parseFloat(rawSignal.price) : 0;

        console.log(`🎯 Received signal: ${symbolInput} ${actionInput}`);

        // 1. Persist (DB or Mock)
        const futuresSymbol = instrumentMapper.getFuturesSymbol(symbolInput);
        const initialData = {
            symbol: futuresSymbol,
            rawSymbol: symbolInput,
            action: actionInput,
            price: priceInput,
            metadata: rawSignal,
            receivedAt: new Date(),
            status: 'pending'
        };

        let signalDoc;
        if (isDbConnected()) {
            signalDoc = await Signal.create(initialData);
        } else {
            signalDoc = {
                ...initialData,
                _id: `mock_sig_${Date.now()}`,
                updateOne: async (u) => Object.assign(signalDoc, u)
            };
            mockStore.signals.push(signalDoc);
        }

        // Notify Signal Received
        notificationService.notifySignalReceived(signalDoc);

        // 2. Step-by-Step Validation & Filter Strategy

        // A. Deduplication (Redis-backed)
        const isDup = await deduplication.isDuplicate(rawSignal);
        if (isDup) {
            await signalDoc.updateOne({ status: 'duplicate' });
            return res.status(200).json({ status: "ignored", reason: "duplicate" });
        }

        // B. Market Hours
        if (!marketHours.isMarketOpen()) {
            await signalDoc.updateOne({ status: 'rejected', rejectionReason: 'outside_market_hours' });
            return res.status(200).json({ status: "ignored", reason: "market_closed" });
        }

        // 3. Single-Position Signal Reversal Engine (BUY 🔄 SELL)
        let trade = null;
        if (config.takePositions) {
            const mt5OrderManager = require('../services/mt5OrderManager');
            let tradeQuantity = rawSignal.quantity || config.mt5.defaultLotSize || 1.0;
            if (futuresSymbol === 'BTC') tradeQuantity = 1.0;

            // Check for existing active open trade for this symbol
            const activeTrade = isDbConnected()
                ? await Trade.findOne({ symbol: futuresSymbol, status: { $in: ['OPEN', 'PENDING', 'QUEUED'] } }).sort({ createdAt: -1 })
                : mockStore.trades.find(t => (t.symbol === futuresSymbol || t.symbol === symbolInput) && (t.status === 'OPEN' || t.status === 'PENDING'));


            const pendingReverse = Array.from(
                mt5OrderManager.pendingOrders.values()
            ).find(order => {
                const orderSymbol =
                    instrumentMapper.getFuturesSymbol(order.symbol || '');

                return (
                    orderSymbol === futuresSymbol &&
                    order.type === 'REVERSE'
                );
            });

            if (pendingReverse) {
                console.log(
                    `⏳ Reversal already pending for ${futuresSymbol}: ${pendingReverse.orderId}`
                );

                await signalDoc.updateOne({
                    status: 'ignored',
                    rejectionReason: 'reversal_already_pending'
                });

                return res.status(200).json({
                    status: 'ignored',
                    reason: 'reversal_already_pending'
                });
            }

            if (activeTrade) {
                const isSameDirection = activeTrade.action.toUpperCase() === actionInput.toUpperCase();
                if (isSameDirection) {
                    console.log(`ℹ️ Signal ignored: Already holding an active ${actionInput} position for ${futuresSymbol}. No stacking allowed.`);
                    await signalDoc.updateOne({ status: 'ignored', rejectionReason: 'same_direction_position_exists' });
                    return res.status(200).json({ status: "ignored", reason: "same_direction_position_exists" });
                }

                // Atomic Reversal: Close existing opposite position & Open new position
                console.log(`🔄 REVERSAL SIGNAL: Flipping position from ${activeTrade.action} to ${actionInput} for ${futuresSymbol}...`);
                trade = await tradeLifecycle.initiateTrade(signalDoc._id, futuresSymbol, actionInput, tradeQuantity, rawSignal.price);
                await mt5OrderManager.createReverseOrder(trade, activeTrade, rawSignal);
            } else {
                // First trade initiation when no active position exists
                trade = await tradeLifecycle.initiateTrade(signalDoc._id, futuresSymbol, actionInput, tradeQuantity, rawSignal.price);
                await mt5OrderManager.createOrder(trade, rawSignal);
            }
        } else {
            console.log(`ℹ️ Signal received & alerted, but active position taking is DISABLED (TAKE_POSITIONS=false).`);
            await signalDoc.updateOne({ status: 'signal_only' });
        }

        // 5. Broadcast to Dashboard & Mobile App via WebSocket & Push Notification (Works in COLD / CLOSED state)
        socketService.emitEvent('signal_received', {
            id: signalDoc._id,
            symbol: futuresSymbol,
            action: rawSignal.action,
            price: rawSignal.price,
            receivedAt: signalDoc.receivedAt || new Date().toISOString(),
            tradeId: trade ? trade._id : null
        });

        // Dispatch High-Priority Push Notification to mobile devices
        pushNotificationService.sendSignalNotification(signalDoc).catch(err => {
            logError(`Push notification dispatch warning: ${err.message}`);
        });

        // 8. Log success
        logSignal(signalDoc, 'accepted');

        // Return 202 Accepted to TradingView
        res.status(202).json({
            status: "accepted",
            signalId: signalDoc._id,
            tradeId: trade ? trade._id : null,
            positionTaken: config.takePositions
        });

    } catch (error) {
        logError(`Signal processing failed: ${error.message}`, { body: req.body });
        res.status(500).json({ error: "Processing Error" });
    }
};

/**
 * Enhanced Dashboard Data Method
 */
const getDashboard = async (req, res) => {
    try {
        const riskStats = await riskManager.getStats();
        const activeTrades = isDbConnected() ? await Trade.find({ status: 'OPEN' }) : mockStore.trades.filter(t => t.status === 'OPEN');
        const redisClient = require('../utils/redis');

        res.json({
            totalSignalsToday: isDbConnected() ? await Signal.countDocuments() : mockStore.signals.length,
            activePositions: activeTrades.length,
            dailyPnl: riskStats.dailyPnl || 0,
            lastSignals: isDbConnected() ? await Signal.find().sort({ receivedAt: -1 }).limit(10) : mockStore.signals.slice(-10).reverse(),
            status: riskStats.isStopped ? "stopped" : "active",
            riskStats: { ...riskStats, isRedisMock: !!redisClient.isMock, isDbMock: !isDbConnected() }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

const getSignals = async (req, res) => {
    res.json(isDbConnected() ? await Signal.find().sort({ receivedAt: -1 }) : [...mockStore.signals].reverse());
};

/**
 * Register Push Token from Mobile App
 */
const registerPushToken = async (req, res) => {
    try {
        const { token, platform, deviceId } = req.body || {};
        if (!token) {
            return res.status(400).json({ error: "Push token is required" });
        }
        const record = await pushNotificationService.registerDeviceToken({ token, platform, deviceId });
        res.status(200).json({ status: "success", message: "Push token registered successfully", data: record });
    } catch (error) {
        logError(`Failed to register push token: ${error.message}`);
        res.status(500).json({ error: "Failed to register push token" });
    }
};

/**
 * Delete Individual Signal by ID
 */
const deleteSignal = async (req, res) => {
    try {
        const { id } = req.params;
        if (isDbConnected() && mongoose.Types.ObjectId.isValid(id)) {
            const deleted = await Signal.findByIdAndDelete(id);
            if (deleted && deleted.tradeId) {
                await Trade.findByIdAndDelete(deleted.tradeId);
            }
        }
        mockStore.signals = mockStore.signals.filter(s => String(s._id) !== String(id));
        mockStore.trades = mockStore.trades.filter(t => String(t.signalId) !== String(id) && String(t._id) !== String(id));
        res.json({ status: 'success', message: 'Signal deleted successfully', id });
    } catch (error) {
        logError(`Failed to delete signal ${req.params.id}: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
};

/**
 * Clear All Signals
 */
const clearAllSignals = async (req, res) => {
    try {
        if (isDbConnected()) {
            await Signal.deleteMany({});
            await Trade.deleteMany({});
        }
        mockStore.signals = [];
        mockStore.trades = [];
        res.json({ status: 'success', message: 'All signals and trade records cleared' });
    } catch (error) {
        logError(`Failed to clear signals: ${error.message}`);
        res.status(500).json({ error: error.message });
    }
};

module.exports = { postSignal, getDashboard, getSignals, registerPushToken, deleteSignal, clearAllSignals, mockStore };
