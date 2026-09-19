/**
 * Validation Middleware for TradingView signals
 */
const validateSignal = (req, res, next) => {
    const { symbol, action, price } = req.body;

    if (!symbol || !action || !price) {
        return res.status(400).json({
            error: "Missing required fields",
            required: ["symbol", "action", "price"]
        });
    }

    const validActions = ["BUY", "SELL"];
    if (!validActions.includes(action.toUpperCase())) {
        return res.status(400).json({
            error: "Invalid action",
            allowed: validActions
        });
    }

    next();
};

module.exports = { validateSignal };
