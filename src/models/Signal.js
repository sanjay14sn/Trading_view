const mongoose = require('mongoose');

const signalSchema = new mongoose.Schema({
    symbol: { type: String, required: true, index: true },
    rawSymbol: { type: String }, // original symbol from TradingView
    action: { type: String, required: true, enum: ['BUY', 'SELL'] },
    price: { type: Number, required: true },
    quantity: { type: Number },
    receivedAt: { type: Date, default: Date.now, index: true },
    status: {
        type: String,
        enum: ['pending', 'accepted', 'duplicate', 'rejected', 'risk_blocked'],
        default: 'pending'
    },
    rejectionReason: { type: String },
    tradeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Trade' },
    metadata: { type: Map, of: String } // any extra TradingView data
}, { timestamps: true });

// Compound index for efficient queries
signalSchema.index({ symbol: 1, receivedAt: -1 });

module.exports = mongoose.model('Signal', signalSchema);
