const mongoose = require('mongoose');

const tradeSchema = new mongoose.Schema({
    signalId: { type: mongoose.Schema.Types.ObjectId, ref: 'Signal', index: true },
    symbol: { type: String, required: true, index: true },
    action: { type: String, required: true, enum: ['BUY', 'SELL'] },
    quantity: { type: Number, required: true },
    entryPrice: { type: Number },
    exitPrice: { type: Number },
    entryTime: { type: Date, default: Date.now, index: true },
    exitTime: { type: Date },
    status: {
        type: String,
        enum: ['PENDING', 'QUEUED', 'OPEN', 'PARTIAL', 'FILLED', 'SL_HIT', 'TARGET_HIT', 'TIMED_EXIT', 'CANCELLED', 'FAILED'],
        default: 'PENDING',
        index: true
    },
    kiteOrderId: { type: String, index: true },
    kiteExitOrderId: { type: String },
    sl: { type: Number },          // Stop Loss
    target: { type: Number },      // Target Price
    pnl: { type: Number },         // Profit/Loss
    charges: { type: Number },     // Estimated charges
    tags: [String]
}, { timestamps: true });

// Compound index for active positions
tradeSchema.index({ status: 1, entryTime: -1 });

module.exports = mongoose.model('Trade', tradeSchema);
