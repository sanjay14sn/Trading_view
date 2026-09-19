const cron = require('node-cron');
const riskManager = require('../services/riskManager');
const pnlService = require('../services/pnlService');
const sessionManager = require('../services/sessionManager');
const { logAction, logError } = require('./logger');

/**
 * Cron Jobs
 * Scheduled tasks for system maintenance and reporting.
 */
const setupCronJobs = () => {
    // 1. Midnight Reset (00:01 AM IST)
    // Clear Redis risk keys and reset daily counters in DB
    cron.schedule('1 0 * * *', async () => {
        try {
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 1);
            const dateStr = yesterday.toISOString().split('T')[0];

            console.log(`🕒 Running Midnight Reset & Report for ${dateStr}`);

            // Generate P&L report for yesterday
            await pnlService.generateDailyReport(dateStr);

            // Note: Redis keys for risk/cooldown will naturally expire or can be cleared
            logAction('SYSTEM_DAILY_RESET', { date: dateStr });
        } catch (error) {
            logError(`Midnight cron failed: ${error.message}`);
        }
    }, {
        timezone: "Asia/Kolkata"
    });

    // 2. Token Refresh Warning (8:30 AM IST)
    // Check if we have a Zerodha token before market opens
    cron.schedule('30 8 * * *', async () => {
        try {
            const hasToken = await sessionManager.hasValidSession();
            if (!hasToken) {
                console.warn('⚠️ WARNING: No Zerodha access token found! Please login before 9:15 AM.');
                // Here you could send a Telegram alert
            }
        } catch (error) {
            logError(`Token check cron failed: ${error.message}`);
        }
    }, {
        timezone: "Asia/Kolkata"
    });

    console.log('⏰ Cron Jobs scheduled');
};

module.exports = setupCronJobs;
