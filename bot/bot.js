const puppeteer = require('puppeteer');
const axios = require('axios');
require('dotenv').config();
const path = require('path');
const fs = require('fs');

// Use real system Chrome (not bundled Chromium) so it can read your login sessions
const CHROME_PATHS = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
];
const CHROME_EXEC = CHROME_PATHS.find(p => fs.existsSync(p));

const CHART_URL = process.env.CHART_URL;
const WEBHOOK_URL = process.env.WEBHOOK_URL;
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL) || 500;
const TICKER = process.env.TICKER || 'UNKNOWN';
const USER_DATA_DIR = process.env.USER_DATA_DIR
    ? path.resolve(process.env.USER_DATA_DIR)
    : path.resolve('../tradingview_user_data');

let lastSignal = null; // Tracks 'SELL' or 'BUY'

async function sendWebhook(action, price) {
    try {
        const payload = {
            symbol: TICKER,
            action: action,
            price: price || 'N/A',
            passphrase: process.env.TRADINGVIEW_PASSPHRASE
        };
        console.log(`[${new Date().toISOString()}] Sending Webhook:`, payload);
        await axios.post(WEBHOOK_URL, payload);
        console.log(`[${new Date().toISOString()}] Webhook sent successfully.`);
    } catch (error) {
        let msg = error.message;
        if (error.response && error.response.data) {
            msg += ` - ${JSON.stringify(error.response.data)}`;
        }
        console.error(`[${new Date().toISOString()}] Error sending webhook:`, msg);
    }
}

// Errors caused by TradingView SPA navigation — safe to skip and retry
function isTransientFrameError(msg) {
    return (
        msg.includes('detached Frame') ||
        msg.includes('Execution context was destroyed') ||
        msg.includes('Cannot find context with specified id') ||
        msg.includes('Session closed')
    );
}

async function startBot() {
    console.log(`[${new Date().toISOString()}] Starting TradingView Monitor Bot...`);
    console.log(`[${new Date().toISOString()}] Profile: ${USER_DATA_DIR}`);

    let browser;
    try {
        try {
            console.log(`[${new Date().toISOString()}] Connecting to Chrome on port 9222...`);
            // Connect to Chrome that YOU launched manually with remote debugging
            browser = await puppeteer.connect({
                browserURL: 'http://localhost:9222',
                defaultViewport: null
            });
            console.log(`[${new Date().toISOString()}] Connected to existing Chrome instance.`);
        } catch (connectError) {
            console.warn(`[${new Date().toISOString()}] Could not connect to Chrome on 9222. Attempting to launch Chrome...`);

            if (!CHROME_EXEC) {
                throw new Error('Chrome executable not found. Please set CHROME_PATHS correctly in bot.js');
            }

            browser = await puppeteer.launch({
                executablePath: CHROME_EXEC,
                headless: false, // Must be false for TradingView
                defaultViewport: null,
                userDataDir: USER_DATA_DIR,
                args: [
                    '--remote-debugging-port=9222',
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-blink-features=AutomationControlled'
                ]
            });
            console.log(`[${new Date().toISOString()}] Chrome launched successfully.`);
        }

        const page = await browser.newPage();
        page.on('console', msg => console.log(`[PAGE LOG] ${msg.text()}`));

        // Remove navigator.webdriver flag so TradingView doesn't block Puppeteer
        await page.evaluateOnNewDocument(() => {
            Object.defineProperty(navigator, 'webdriver', { get: () => false });
        });

        console.log(`[${new Date().toISOString()}] Navigating to: ${CHART_URL}`);
        await page.goto(CHART_URL, { waitUntil: 'networkidle2', timeout: 60000 });

        // Scroll chart to the end (latest data)
        console.log(`[${new Date().toISOString()}] Scrolling chart to latest candles...`);
        await page.keyboard.press('End');
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Save debug screenshot to verify chart loaded
        const debugPath = path.resolve('debug_chart.png');
        await page.screenshot({ path: debugPath });
        console.log(`[${new Date().toISOString()}] Debug screenshot saved.`);

        console.log(`[${new Date().toISOString()}] Chart loaded. Starting monitoring loop...`);

        let lastHeartbeat = Date.now();
        let isFirstDetection = true;

        while (true) {
            if (!browser.isConnected()) {
                throw new Error('Browser disconnected');
            }

            try {
                const findAllSignals = async () => {
                    const signals = [];

                    // Helper to get ALL text from all sources
                    const findInRoot = (root) => {
                        const all = root.querySelectorAll("*");
                        for (const el of Array.from(all)) {
                            const text = (el.innerText || el.textContent || "").toUpperCase().trim();
                            const rect = el.getBoundingClientRect();

                            // Check for Alert Log Entry
                            const isJSON = text.includes("{") && text.includes("}");
                            // Use simpler keyword match to be more flexible
                            const hasSignalData = text.includes("ACTION") || text.includes("SYMBOL");
                            const isMetadata = text.includes("INITDATA") || text.includes("USER");

                            if (isJSON && hasSignalData && !isMetadata) {
                                signals.push({
                                    text: text.includes("SELL") ? "SELL (ALERT)" : "BUY (ALERT)",
                                    right: 9999,
                                    source: 'ALERT_LOG',
                                    raw: text
                                });
                            }

                            // Check for Chart Label (Position > 400 to avoid buttons, Must have @)
                            const hasSignalKeyword = text.includes("BUY") || text.includes("SELL");
                            const hasAtSymbol = text.includes("@");

                            if (hasSignalKeyword && hasAtSymbol && rect.right > 400 && text.length < 30) {
                                signals.push({
                                    text: text,
                                    right: rect.right,
                                    source: 'CHART',
                                    raw: text
                                });
                            }

                            if (el.shadowRoot) findInRoot(el.shadowRoot);
                        }
                    };

                    findInRoot(document);
                    return signals;
                };

                const allSignals = await page.evaluate(findAllSignals);

                const signalData = (() => {
                    if (allSignals.length === 0) return null;

                    // Pick rightmost one
                    const latest = allSignals.sort((a, b) => b.right - a.right)[0];
                    const action = latest.text.includes("SELL") ? "SELL" : "BUY";

                    return {
                        action: action,
                        price: 'PENDING',
                        raw: latest.raw || latest.text,
                        source: latest.source
                    };
                })();

                if (signalData) {
                    const { action, price, raw } = signalData;
                    if (raw !== lastSignal) {
                        // Clean price: Extract only the main price
                        let cleanPrice = 0;
                        const pData = await page.evaluate(() => {
                            let p = 'N/A';
                            const selectors = ['.last-price-value', '[class*="last-price"]', '[class*="lastPrice"]'];
                            for (const s of selectors) {
                                const el = document.querySelector(s);
                                if (el && el.textContent.trim()) { p = el.textContent.trim(); break; }
                            }
                            return p;
                        });

                        const matches = pData.match(/(\d{1,3}(,\d{3})*(\.\d+)?)/g);
                        if (matches && matches.length > 0) {
                            const numericValues = matches.map(m => parseFloat(m.replace(/,/g, '')));
                            cleanPrice = Math.max(...numericValues);
                        }

                        if (isFirstDetection) {
                            console.log(`[${new Date().toISOString()}] INITIAL SIGNAL DETECTED (Startup): ${action} | Source: ${signalData.source}`);
                            console.log(`[DEBUG] Raw Text: "${raw.substring(0, 50)}..."`);
                            lastSignal = raw;
                            isFirstDetection = false;
                        } else {
                            console.log(`[${new Date().toISOString()}] NEW SIGNAL: ${action} | Price: ${cleanPrice} | Source: ${signalData.source}`);
                            console.log(`[DEBUG] Raw Text: "${raw.substring(0, 50)}..."`);
                            await sendWebhook(action, cleanPrice);
                            lastSignal = raw;
                        }
                    }
                }

                // If we've completed a poll and no signal found, we're no longer in "First Detection" 
                // but we might want to wait until we see ONE signal to "seed" the state.
                // The current logic seeds it ONCE it sees something.

            } catch (loopError) {
                if (isTransientFrameError(loopError.message)) {
                    console.warn(`[${new Date().toISOString()}] Frame transient error (skipping): ${loopError.message}`);
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    continue;
                }
                console.error(`[${new Date().toISOString()}] Loop Error:`, loopError.message);
                break;
            }

            if (Date.now() - lastHeartbeat >= 10000) {
                console.log(`[${new Date().toISOString()}] Bot is listening for signals...`);
                lastHeartbeat = Date.now();
            }

            await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL));
        }
    } catch (error) {
        console.error(`[${new Date().toISOString()}] Bot Error:`, error.message);
    } finally {
        if (browser) {
            try { await browser.close(); } catch (_) { }
        }
        console.log(`[${new Date().toISOString()}] Browser closed. Restarting in 5 seconds...`);
        setTimeout(startBot, 5000);
    }
}

startBot();
