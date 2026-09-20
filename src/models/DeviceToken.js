const mongoose = require('mongoose');

const deviceTokenSchema = new mongoose.Schema({
    token: {
        type: String,
        required: true,
        unique: true,
        trim: true
    },
    platform: {
        type: String,
        enum: ['android', 'ios', 'web', 'unknown'],
        default: 'android'
    },
    deviceId: {
        type: String,
        default: ''
    },
    lastActive: {
        type: Date,
        default: Date.now
    }
}, { timestamps: true });

// Memory fallback store if MongoDB is offline
const memoryTokens = new Map();

deviceTokenSchema.statics.registerToken = async function(tokenData) {
    const { token, platform, deviceId } = tokenData;
    if (!token) return null;

    try {
        if (mongoose.connection.readyState === 1) {
            return await this.findOneAndUpdate(
                { token },
                { token, platform: platform || 'android', deviceId: deviceId || '', lastActive: new Date() },
                { upsert: true, new: true }
            );
        }
    } catch (err) {
        console.warn('⚠️  MongoDB unavailable for DeviceToken, using memory store fallback:', err.message);
    }

    // Fallback to in-memory store
    const existing = memoryTokens.get(token) || {};
    const updated = {
        token,
        platform: platform || 'android',
        deviceId: deviceId || '',
        lastActive: new Date(),
        createdAt: existing.createdAt || new Date(),
        updatedAt: new Date()
    };
    memoryTokens.set(token, updated);
    return updated;
};

deviceTokenSchema.statics.getAllTokens = async function() {
    try {
        if (mongoose.connection.readyState === 1) {
            const docs = await this.find().select('token platform -_id');
            return docs.map(d => d.token);
        }
    } catch (err) {
        console.warn('⚠️  MongoDB unavailable for getAllTokens, returning memory tokens:', err.message);
    }
    return Array.from(memoryTokens.keys());
};

module.exports = mongoose.model('DeviceToken', deviceTokenSchema);
