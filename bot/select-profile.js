#!/usr/bin/env node
/**
 * select-profile.js
 * Scans your Chrome profiles, shows their name/email,
 * and updates USER_DATA_DIR in bot/.env automatically.
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const CHROME_DIR = path.join(
    process.env.HOME,
    'Library/Application Support/Google/Chrome'
);
const ENV_FILE = path.join(__dirname, '.env');

// ── Collect profiles ────────────────────────────────────────────────────────

function getProfiles() {
    const entries = fs.readdirSync(CHROME_DIR);
    const profiles = [];

    for (const entry of entries) {
        if (entry !== 'Default' && !entry.startsWith('Profile')) continue;
        const prefsPath = path.join(CHROME_DIR, entry, 'Preferences');
        if (!fs.existsSync(prefsPath)) continue;

        try {
            const prefs = JSON.parse(fs.readFileSync(prefsPath, 'utf8'));
            const name = prefs?.profile?.name || entry;
            const email = prefs?.account_info?.[0]?.email || '';
            profiles.push({ folder: entry, name, email });
        } catch (_) {
            // skip unreadable profiles
        }
    }

    return profiles;
}

// ── Update .env ─────────────────────────────────────────────────────────────

function updateEnv(profilePath) {
    let content = fs.readFileSync(ENV_FILE, 'utf8');
    if (/^USER_DATA_DIR=/m.test(content)) {
        content = content.replace(/^USER_DATA_DIR=.*/m, `USER_DATA_DIR=${profilePath}`);
    } else {
        content += `\nUSER_DATA_DIR=${profilePath}`;
    }
    fs.writeFileSync(ENV_FILE, content, 'utf8');
}

// ── Main ─────────────────────────────────────────────────────────────────────

const profiles = getProfiles();

if (profiles.length === 0) {
    console.error('No Chrome profiles found in:', CHROME_DIR);
    process.exit(1);
}

console.log('\n📂  Available Chrome Profiles\n');
profiles.forEach((p, i) => {
    const label = p.email ? `${p.name} (${p.email})` : p.name;
    console.log(`  [${i + 1}]  ${label}   — ${p.folder}`);
});
console.log();

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

rl.question('Enter the number of the profile to use: ', (answer) => {
    rl.close();
    const idx = parseInt(answer, 10) - 1;

    if (isNaN(idx) || idx < 0 || idx >= profiles.length) {
        console.error('❌  Invalid selection.');
        process.exit(1);
    }

    const chosen = profiles[idx];
    const fullPath = path.join(CHROME_DIR, chosen.folder);

    updateEnv(fullPath);

    const label = chosen.email ? `${chosen.name} (${chosen.email})` : chosen.name;
    console.log(`\n✅  Profile set to: ${label}`);
    console.log(`    USER_DATA_DIR=${fullPath}`);
    console.log('\n▶   Now run:  node bot.js\n');
});
