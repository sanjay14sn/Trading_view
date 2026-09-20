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

        // C. Risk Management (Concurrent trades, Daily limits, Cooldowns)
        const riskResult = await riskManager.canTrade(rawSignal);
        if (!riskResult.allowed) {
            await signalDoc.updateOne({ status: 'risk_blocked', rejectionReason: riskResult.reason });
            notificationService.notifyRiskAlert(riskResult.reason, riskResult.stats);
            return res.status(200).json({ status: "ignored", reason: riskResult.reason });
        }

        // 3. Mapping & Pre-processing (already done above)

        // 4. Trade Initiation (Skipped if config.takePositions is false)
        let trade = null;
        if (config.takePositions) {
            const tradeQuantity = rawSignal.quantity || 1;
            trade = await tradeLifecycle.initiateTrade(signalDoc._id, futuresSymbol, rawSignal.action.toUpperCase(), tradeQuantity, rawSignal.price);

            // Queue for Asynchronous Zerodha Execution (BullMQ)
            await addOrderToQueue({
                symbol: futuresSymbol,
                action: rawSignal.action.toUpperCase(),
                quantity: tradeQuantity,
                price: rawSignal.price
            }, trade._id);

            // Start Cooldown for this symbol
            await riskManager.startCooldown(futuresSymbol);
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
    res.json(isDbConnected() ? await Signal.find().sort({ receivedAt: -1 }).limit(50) : mockStore.signals.slice(-50).reverse());
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

module.exports = { postSignal, getDashboard, getSignals, registerPushToken, mockStore };
