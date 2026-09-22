/**
 * Render each service in a real browser and report what is actually on screen.
 *
 * An HTTP 200 is not evidence that a page works. A single-page app returns 200
 * and an empty shell whether or not its API answered, so this captures the
 * things that actually distinguish the two: the rendered heading, visible text,
 * console errors, and failed sub-requests — plus a screenshot to look at.
 *
 * TLS is deliberately NOT bypassed. There is no ignoreHTTPSErrors here, so the
 * run only passes if Chrome validates the certificate chain against the OS
 * trust store. Managed Chrome can also require online revocation for a local
 * anchor, so this exercises the issuer-signed CRLs as well as dev-ca-trust.
 * That makes it a genuine PKI check, not just a routing check. A cert failure
 * must look different from a 404 — with ignoreHTTPSErrors they look identical.
 *
 * Usage:
 *   node browser-check.mjs --out <dir> [--port 443] [host ...]
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const getArg = (name, dflt) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : dflt;
};
const outDir = getArg('--out', './browser-check');
const port = getArg('--port', '443');
// ':443' is implicit; only append a non-standard port.
const portSuffix = port === '443' ? '' : `:${port}`;
const manifest = getArg('--services', null);
const only = getArg('--only', null);

// Targets come either from the manifest (name/host/path/expect) or bare hosts on
// the command line. The manifest form is preferred: several services 404 on /
// while working on their real entry point, so checking / and reporting a failure
// would send someone hunting a routing bug that does not exist.
let targets;
if (manifest) {
  const cfg = JSON.parse(fs.readFileSync(manifest, 'utf8'));
  targets = cfg.services;
  if (only) {
    const wanted = new Set(only.split(','));
    targets = targets.filter(s => wanted.has(s.name));
  }
} else {
  targets = args
    .filter((a, i) => !a.startsWith('--') &&
      !['--out', '--port', '--services', '--only'].includes(args[i - 1]))
    .map(h => ({ name: h, host: h, path: '/' }));
}

if (targets.length === 0) {
  console.error('no targets given (use --services <file> or list hosts)');
  process.exit(2);
}
fs.mkdirSync(outDir, { recursive: true });

// channel: 'chrome' uses installed Google Chrome, which reads the platform
// trust store and its managed local-anchor revocation policy. Playwright's
// bundled Chromium can use a different trust path and would not prove that the
// host trust plus CRL setup works.
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const results = [];

for (const svc of targets) {
  const host = svc.host;
  const url = `https://${host}${portSuffix}${svc.path || '/'}`;
  const consoleErrors = [];
  const failedRequests = [];
  const ctx = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const page = await ctx.newPage();

  page.on('console', m => {
    if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 200));
  });
  page.on('requestfailed', r => {
    failedRequests.push(`${r.method()} ${r.url().slice(0, 120)} — ${r.failure()?.errorText}`);
  });
  page.on('response', r => {
    if (r.status() >= 400) {
      failedRequests.push(`HTTP ${r.status()} ${r.url().slice(0, 120)}`);
    }
  });

  const rec = { name: svc.name, host, url, expect: svc.expect || null };
  try {
    const resp = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    rec.status = resp?.status() ?? null;
    // Give client-rendered apps a moment to paint before judging them empty.
    await page.waitForTimeout(3500);
    rec.title = (await page.title()) || '(none)';
    rec.heading = await page.evaluate(() => {
      const h = document.querySelector('h1,h2,[role="heading"]');
      return h ? h.textContent.trim().slice(0, 120) : null;
    });
    rec.visibleChars = await page.evaluate(() => (document.body?.innerText || '').trim().length);
    rec.textSample = await page.evaluate(() =>
      (document.body?.innerText || '').trim().replace(/\s+/g, ' ').slice(0, 160));
    const shot = path.join(outDir, `${host.replace(/[^a-z0-9.-]/gi, '_')}.png`);
    await page.screenshot({ path: shot, fullPage: false });
    rec.screenshot = shot;
  } catch (e) {
    rec.error = String(e.message || e).split('\n')[0].slice(0, 200);
  }

  rec.consoleErrors = consoleErrors;
  rec.failedRequests = failedRequests;

  // A page that loaded but rendered almost nothing, or rendered the wrong thing,
  // is the failure this script exists to catch — both are invisible to a
  // status-code check.
  const body = (rec.textSample || '') + ' ' + (rec.title || '');
  const contentOk = !svc.expect ||
    body.toLowerCase().includes(String(svc.expect).toLowerCase());
  rec.verdict =
    rec.error ? 'FAIL(load)' :
    rec.status !== 200 ? `FAIL(http ${rec.status})` :
    // 20 chars is the default floor for "rendered nothing". Some services
    // legitimately answer with less - ollama's entire root response is the
    // 17-character string "Ollama is running" - so a service may lower it
    // with minChars. It is per-service and must be justified in services.json,
    // because a check that reports a false failure gets ignored, and then the
    // real failures get ignored with it.
    rec.visibleChars < (svc.minChars ?? 20) ? 'FAIL(blank page)' :
    !contentOk ? `FAIL(missing "${svc.expect}")` :
    consoleErrors.length ? 'WARN(console errors)' :
    'OK';

  results.push(rec);
  console.log(
    `${rec.verdict.padEnd(24)} ${(svc.name || host).padEnd(20)} ` +
    `http=${rec.status ?? '-'} chars=${rec.visibleChars ?? '-'} ` +
    `consoleErr=${consoleErrors.length} failedReq=${failedRequests.length}` +
    (rec.title ? ` | "${rec.title}"` : '') +
    (rec.error ? ` | ${rec.error}` : '')
  );
  await ctx.close();
}

await browser.close();
fs.writeFileSync(path.join(outDir, 'results.json'), JSON.stringify(results, null, 2));

const bad = results.filter(r => r.verdict.startsWith('FAIL'));
console.log(`\n${results.length} checked, ${bad.length} failed`);
if (bad.length) {
  for (const r of bad) console.log(`  ${r.host}: ${r.verdict}`);
}
process.exit(bad.length ? 1 : 0);
