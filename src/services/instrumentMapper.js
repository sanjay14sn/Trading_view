/**
 * Futures Mapping Service
 * Maps spot symbols to their current month futures counterparts.
 */

const mapping = {
    'BTC': 'BTCUSD',
    'BTCUSD': 'BTCUSD',
    'BTCUSDT': 'BTCUSD',
    'XAUUSD': 'XAUUSD',
    'GOLD': 'XAUUSD'
};

const getFuturesSymbol = (spotSymbol) => {
    if (!spotSymbol) return 'BTCUSD';
    const clean = spotSymbol.toUpperCase().replace(/[^A-Z0-9]/g, '');
    return mapping[clean] || clean || 'BTCUSD';
};

module.exports = { getFuturesSymbol };
