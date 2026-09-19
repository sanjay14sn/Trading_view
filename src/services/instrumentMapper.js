/**
 * Futures Mapping Service
 * Maps spot symbols to their current month futures counterparts.
 */

const mapping = {
    'NIFTY': 'NIFTY FUT',
    'BANKNIFTY': 'BANKNIFTY FUT',
    'FINNIFTY': 'FINNIFTY FUT'
};

const getFuturesSymbol = (spotSymbol) => {
    return mapping[spotSymbol.toUpperCase()] || spotSymbol;
};

module.exports = { getFuturesSymbol };
