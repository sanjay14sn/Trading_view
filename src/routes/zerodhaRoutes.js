const express = require('express');
const router = express.Router();
const zerodhaController = require('../controllers/zerodhaController');

/**
 * Zerodha Authentication Routes
 * Path: /api/zerodha
 */
router.get('/auth/login', zerodhaController.initiateLogin);
router.get('/callback', zerodhaController.handleCallback); // Matches /api/zerodha/callback
router.get('/auth/status', zerodhaController.checkSession);

module.exports = router;
