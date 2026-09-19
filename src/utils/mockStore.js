/**
 * Centralized Mock Store
 * Used when MongoDB or Redis are unavailable to maintain system state in memory.
 */
const mockStore = {
    signals: [],
    trades: [],

    // Helper to get active trades
    getActiveTrades() {
        return this.trades.filter(t => t.status === 'OPEN' || t.status === 'PENDING');
    },

    // Helper to get today's trades
    getTodayTrades() {
        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);
        return this.trades.filter(t => new Date(t.createdAt || t.entryTime) >= startOfDay);
    }
};

module.exports = mockStore;
