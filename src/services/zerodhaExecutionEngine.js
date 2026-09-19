const KiteConnect = require('kiteconnect').KiteConnect;
const config = require('../config');
const sessionManager = require('./sessionManager');
const { logError, logOrder } = require('../utils/logger');

/**
 * Zerodha Execution Engine
 * Handles direct interaction with Kite Connect API.
 */
class ZerodhaExecutionEngine {
    constructor() {
        this.apiKey = config.zerodha.apiKey;
        this.apiSecret = config.zerodha.apiSecret;
        this.kite = new KiteConnect({ api_key: this.apiKey });
    }

    /**
     * Initialize the kite instance with the current access token
     */
    async _init() {
        const accessToken = await sessionManager.getAccessToken();
        if (!accessToken) {
            throw new Error('No valid Zerodha access token found. Please login.');
        }
        this.kite.setAccessToken(accessToken);
    }

    /**
     * Place a regular market order
     */
    async placeOrder(params) {
        try {
            await this._init();

            const orderParams = {
                exchange: params.exchange || 'NFO',
                tradingsymbol: params.symbol,
                transaction_type: params.action, // BUY or SELL
                quantity: params.quantity,
                product: params.product || 'MIS', // Intraday
                order_type: 'MARKET',
                validity: 'DAY'
            };

            const response = await this.kite.placeOrder('regular', orderParams);

            logOrder('placed', {
                symbol: params.symbol,
                orderId: response.order_id,
                action: params.action
            });

            return response.order_id;
        } catch (error) {
            logError(`Zerodha placeOrder error: ${error.message}`, { params });
            throw error;
        }
    }

    /**
     * Get order details/status
     */
    async getOrderHistory(orderId) {
        try {
            await this._init();
            return await this.kite.getOrderHistory(orderId);
        } catch (error) {
            logError(`Zerodha getOrderHistory error: ${error.message}`, { orderId });
            return null;
        }
    }

    /**
     * Get real-time quotes for a symbol
     */
    async getQuote(symbols) {
        try {
            await this._init();
            return await this.kite.getQuote(symbols);
        } catch (error) {
            logError(`Zerodha getQuote error: ${error.message}`, { symbols });
            throw error;
        }
    }
}

// Singleton instance
module.exports = new ZerodhaExecutionEngine();
