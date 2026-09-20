const mongoose = require('mongoose');
const config = require('../config');
const { logError } = require('../utils/logger');

const connectDB = async () => {
    try {
        // Disable buffering so that if DB is down, operations fall back gracefully without hanging
        mongoose.set('bufferCommands', false);

        // Connection status monitoring
        mongoose.connection.on('disconnected', () => {
            console.warn('⚠️  MongoDB disconnected. Attempting auto-reconnect...');
        });

        mongoose.connection.on('reconnected', () => {
            console.log('✅ MongoDB reconnected successfully.');
        });

        mongoose.connection.on('error', (err) => {
            console.error('❌ MongoDB connection error (swallowed):', err.message);
        });

        await mongoose.connect(config.mongodb.uri, {
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 10000,
        });
        console.log(`📡 MongoDB Connected`);
    } catch (err) {
        console.error(`❌ MongoDB connection failed: ${err.message}`);
        console.warn('⚠️  Falling back to In-Memory storage.');
    }
};

module.exports = connectDB;
