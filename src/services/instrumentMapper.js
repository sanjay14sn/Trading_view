/**
 * Futures Mapping Service
 * Maps spot symbols to their current month futures counterparts.
 */

const mapping = {
    'BTC': 'BTC',
    'BTCUSD': 'BTC',
    'BTCUSDT': 'BTC',
    'BITSTAMPBTCUSD': 'BTC',
    'BINANCEBTCUSDT': 'BTC',
    'XAUUSD': 'XAUUSD',
    'GOLD': 'XAUUSD'
};

const getFuturesSymbol = (spotSymbol) => {
    if (!spotSymbol) return 'BTC';
    const clean = spotSymbol.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (clean.startsWith('BTC')) return 'BTC';
    return mapping[clean] || clean || 'BTC';
};

module.exports = { getFuturesSymbol };
