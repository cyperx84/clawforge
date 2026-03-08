#!/usr/bin/env node
/**
 * install-binaries.js — ClawForge postinstall script.
 *
 * Downloads pre-built clawforge-dashboard and clawforge-web binaries
 * from the GitHub release matching the installed package version.
 *
 * Platforms supported: darwin-arm64, darwin-amd64, linux-amd64, linux-arm64
 * Falls back gracefully (warns but does not fail install) if download fails.
 */

'use strict';

const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const pkg = require('../package.json');
const VERSION = pkg.version;
const REPO = 'cyperx84/clawforge';
const BIN_DIR = path.join(__dirname);

function platform() {
  const os = process.platform;
  const arch = process.arch;
  if (os === 'darwin' && arch === 'arm64') return 'darwin-arm64';
  if (os === 'darwin' && (arch === 'x64' || arch === 'ia32')) return 'darwin-amd64';
  if (os === 'linux' && arch === 'arm64') return 'linux-arm64';
  if (os === 'linux' && (arch === 'x64' || arch === 'ia32')) return 'linux-amd64';
  return null;
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const get = (u) => {
      https.get(u, { headers: { 'User-Agent': 'clawforge-installer' } }, (res) => {
        if (res.statusCode === 301 || res.statusCode === 302) {
          return get(res.headers.location);
        }
        if (res.statusCode !== 200) {
          file.close();
          fs.unlink(dest, () => {});
          return reject(new Error(`HTTP ${res.statusCode} for ${u}`));
        }
        res.pipe(file);
        file.on('finish', () => { file.close(); resolve(); });
        file.on('error', (err) => { fs.unlink(dest, () => {}); reject(err); });
      }).on('error', reject);
    };
    get(url);
  });
}

async function main() {
  const plat = platform();
  if (!plat) {
    console.warn(`[clawforge] Unsupported platform ${process.platform}/${process.arch} — skipping binary download.`);
    console.warn('[clawforge] Install from source: https://github.com/cyperx84/clawforge');
    return;
  }

  const binaries = [
    { name: 'clawforge-dashboard', asset: `clawforge-dashboard-${plat}` },
    { name: 'clawforge-web',       asset: `clawforge-web-${plat}` },
  ];

  let anyFailed = false;

  for (const { name, dest_name, asset } of binaries.map(b => ({ ...b, dest_name: b.name }))) {
    const dest = path.join(BIN_DIR, dest_name);
    const url = `https://github.com/${REPO}/releases/download/v${VERSION}/${asset}`;

    // Skip if already present and correct (e.g. re-install)
    if (fs.existsSync(dest)) {
      fs.chmodSync(dest, 0o755);
      continue;
    }

    process.stdout.write(`[clawforge] Downloading ${name} (${plat})... `);
    try {
      await download(url, dest);
      fs.chmodSync(dest, 0o755);
      console.log('✓');
    } catch (err) {
      console.log(`⚠  skipped (${err.message})`);
      anyFailed = true;
    }
  }

  if (anyFailed) {
    console.warn('[clawforge] Some binaries could not be downloaded.');
    console.warn('[clawforge] TUI dashboard and web server may not be available.');
    console.warn('[clawforge] To build from source: cd $(npm root)/@cyperx/clawforge && go build -o bin/clawforge-dashboard ./tui && go build -o bin/clawforge-web ./web');
    console.warn('[clawforge] Or use Homebrew: brew tap cyperx84/tap && brew install clawforge');
  } else {
    console.log('[clawforge] ✅ All binaries installed.');
  }
}

main().catch((err) => {
  // Never fail the npm install — just warn
  console.warn('[clawforge] Binary install warning:', err.message);
});
