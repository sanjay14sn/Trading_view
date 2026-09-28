const { logAction } = require('../utils/logger');
const config = require('../config');

/**
 * MT5 Service
 * Manages connection health, account telemetry, and EA authentication state.
 */
class MT5Service {
    constructor() {
        this.lastHeartbeat = null;
        this.accountInfo = {
            login: null,
            server: 'Hantec-Server',
            balance: 0,
            equity: 0,
            freeMargin: 0,
            leverage: 1,
            currency: 'USD'
        };
        this.isConnected = false;
        this.TIMEOUT_MS = 10000; // 10 seconds timeout for EA heartbeat
    }

    /**
     * Update heartbeat and account state from MT5 EA sync request
     */
    updateState(syncData = {}) {
        this.lastHeartbeat = Date.now();
        this.isConnected = true;

        if (syncData.account) {
            this.accountInfo = {
                ...this.accountInfo,
                ...syncData.account
            };
        }

        logAction('MT5_EA_HEARTBEAT', {
            server: this.accountInfo.server,
            balance: this.accountInfo.balance,
            equity: this.accountInfo.equity
        });
    }

    /**
     * Check if MT5 EA is actively connected
     */
    checkConnectionStatus() {
        if (!this.lastHeartbeat) return false;
        const diff = Date.now() - this.lastHeartbeat;
        this.isConnected = diff < this.TIMEOUT_MS;
        return this.isConnected;
    }

    /**
     * Get system status summary for dashboard and Flutter mobile app
     */
    getStatus() {
        const connected = this.checkConnectionStatus();
        return {
            connected,
            lastHeartbeat: this.lastHeartbeat ? new Date(this.lastHeartbeat).toISOString() : null,
            symbol: config.mt5.symbol,
            magicNumber: config.mt5.magicNumber,
            account: this.accountInfo
        };
    }
}

module.exports = new MT5Service();
