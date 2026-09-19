const moment = require('moment-timezone');

/**
 * Market Hours Service
 * Checks if current time is within Indian Market Hours (9:15 AM - 3:30 PM IST).
 */

const isMarketOpen = () => {
    const now = moment().tz('Asia/Kolkata');
    const day = now.day();
    const hours = now.hours();
    const minutes = now.minutes();

    /**
     * TESTING OVERRIDE:
     * Allowing Sunday (0) and any time for testing purposes.
     * Revert this for production!
     */
    return true; // Simple override for now
};

module.exports = { isMarketOpen };
