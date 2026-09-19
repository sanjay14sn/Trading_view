const mongoose = require('mongoose');
const config = require('../config');
const { logError } = require('../utils/logger');

const connectDB = async () => {
    try {
        // Disable buffering so that if DB is down, it fails fast instead of hanging
        mongoose.set('bufferCommands', false);

        await mongoose.connect(config.mongodb.uri, {
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 10000,
        });
        console.log(`📡 MongoDB Connected`);
    } catch (err) {
        console.error(`❌ MongoDB connection failed: ${err.message}`);
        console.warn('⚠️  Falling back to In-Memory storage (for demo only).');
    }
};

module.exports = connectDB;
