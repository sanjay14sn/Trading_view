const axios = require('axios');
const config = require('../config');

/**
 * Keep-Alive & Watchdog Service
 * Ensures the backend process stays active, prevents server sleep on cloud environments (e.g. Render/VPS),
 * and monitors application health continuously.
 */

let pingInterval = null;

const keepAliveService = {
    start() {
        if (pingInterval) return;

        const port = config.port || 3001;
        const targetUrl = process.env.SELF_KEEP_ALIVE_URL || `http://localhost:${port}/health`;

        console.log(`📡 Keep-Alive Watchdog started (Pinging ${targetUrl} every 3 minutes)`);

        // Perform initial ping after 10s, then repeat every 3 minutes
        setTimeout(() => this._ping(targetUrl), 10000);
        pingInterval = setInterval(() => this._ping(targetUrl), 3 * 60 * 1000);
    },

    stop() {
        if (pingInterval) {
            clearInterval(pingInterval);
            pingInterval = null;
        }
    },

    async _ping(url) {
        try {
            await axios.get(url, { timeout: 5000 });
            // Heartbeat OK
        } catch (err) {
            console.warn(`⚠️ Keep-Alive self-ping check warning (${url}): ${err.message}`);
        }
    }
};

module.exports = keepAliveService;
