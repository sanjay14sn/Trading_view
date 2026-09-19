const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
    timestamp: { type: Date, default: Date.now, index: true },
    action: { type: String, required: true, index: true }, // e.g., ORDER_PLACED, SL_TRIGGERED
    payload: { type: mongoose.Schema.Types.Mixed },
    actor: { type: String, default: 'system' }, // system, user
    level: { type: String, enum: ['info', 'warn', 'error'], default: 'info' },
    tradeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Trade', index: true }
}, { timestamps: false });

module.exports = mongoose.model('AuditLog', auditLogSchema);
