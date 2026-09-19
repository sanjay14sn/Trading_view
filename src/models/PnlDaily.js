const mongoose = require('mongoose');

const pnlDailySchema = new mongoose.Schema({
    date: { type: String, required: true, unique: true, index: true }, // YYYY-MM-DD
    realizedPnl: { type: Number, default: 0 },
    unrealizedPnl: { type: Number, default: 0 },
    totalTrades: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    winRate: { type: Number, default: 0 },
    maxDrawdown: { type: Number, default: 0 },
    charges: { type: Number, default: 0 }
}, { timestamps: true });

module.exports = mongoose.model('PnlDaily', pnlDailySchema);
