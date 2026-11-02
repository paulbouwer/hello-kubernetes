// Takes the README's screenshot of the app (test/screenshot.sh runs it in the
// pinned Playwright image). The page is the real one, from a k3d cluster, with
// one change: the node line's kernel, such as "Linux 6.8.0-49-generic", which
// is the kernel of whatever machine runs k3d, becomes its major version, such
// as "Linux 6.x". The README shouldn't show the details of a maintainer's own
// machine (decided with the maintainer, 2026-11-02, #156).
//
// Usage: node scripts/app-screenshot.mjs <url> <file>
import { chromium } from '@playwright/test';

const [url, file] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 640, height: 480 } });
await page.goto(url, { waitUntil: 'load' });
const changed = await page.evaluate(() => {
  for (const row of document.querySelectorAll('#info tr')) {
    if (row.querySelector('th')?.textContent.trim() !== 'node:') continue;
    const cell = row.querySelector('td');
    const before = cell.textContent;
    cell.textContent = before.replace(/\(Linux (\d+)\.[^)]*\)/, '(Linux $1.x)');
    return before !== cell.textContent;
  }
  return false;
});
if (!changed) {
  console.error('app-screenshot.mjs: no "(Linux …)" on the node line to generalise');
  process.exit(1);
}
await page.waitForTimeout(500);
await page.screenshot({ path: file, fullPage: true });
await browser.close();
