// Checks every page of the built site, in light and dark mode: no console
// errors, no CSP violations, no requests to other sites, and no serious or
// critical accessibility problems (axe). It also saves screenshots of each
// page, desktop and phone, for review (test-results/screenshots).
import { test, expect, type Page } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { readFileSync } from 'node:fs';

const base = '/hello-kubernetes/';
const sitemap = readFileSync(new URL('../dist/sitemap-0.xml', import.meta.url), 'utf8');
const pages = [...sitemap.matchAll(/<loc>https:\/\/paulbouwer\.github\.io(\/hello-kubernetes\/[^<]*)<\/loc>/g)].map(
  (m) => m[1],
);

test('the sitemap lists the pages', () => {
  expect(pages).toContain(base);
  expect(pages.length).toBeGreaterThan(1);
});

// Loads a page, and returns what went wrong on it.
async function visit(page: Page, path: string) {
  const problems: string[] = [];
  page.on('console', (message) => {
    if (message.type() === 'error') problems.push(`console error: ${message.text()}`);
  });
  page.on('pageerror', (error) => problems.push(`page error: ${error.message}`));
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (!['127.0.0.1:4322', ''].includes(url.host) && !url.protocol.startsWith('data')) {
      problems.push(`request to another site: ${request.url()}`);
    }
  });
  await page.addInitScript(() => {
    document.addEventListener('securitypolicyviolation', (event) => {
      console.error(`CSP violation: ${event.violatedDirective} ${event.blockedURI}`);
    });
  });
  const response = await page.goto(path, { waitUntil: 'networkidle' });
  expect(response?.status(), `${path} returned ${response?.status()}`).toBe(200);
  return problems;
}

for (const scheme of ['light', 'dark'] as const) {
  test.describe(`${scheme} mode`, () => {
    test.use({ colorScheme: scheme });

    for (const path of pages) {
      test(`${path} loads cleanly`, async ({ page }) => {
        const problems = await visit(page, path);
        const name = path.replace(base, '').replace(/\/$/, '').replaceAll('/', '-') || 'index';
        await page.setViewportSize({ width: 1440, height: 1000 });
        await page.screenshot({ path: `test-results/screenshots/${name}-${scheme}-desktop.png`, fullPage: true });
        await page.setViewportSize({ width: 390, height: 844 });
        await page.screenshot({ path: `test-results/screenshots/${name}-${scheme}-phone.png`, fullPage: true });
        expect(problems).toEqual([]);
      });

      test(`${path} has no serious accessibility problems`, async ({ page }) => {
        await page.goto(path, { waitUntil: 'networkidle' });
        const results = await new AxeBuilder({ page }).analyze();
        // One known exception: Starlight's search button shows "Search Ctrl K"
        // and is named "Search". axe reports the keyboard hint as a label
        // mismatch, but the label, "Search", is in the name, as WCAG 2.5.3
        // asks. Only this rule, on only this button, is ignored.
        for (const v of results.violations) {
          if (v.id === 'label-content-name-mismatch') {
            v.nodes = v.nodes.filter((n) => String(n.target) !== 'button[data-open-modal=""]');
          }
        }
        results.violations = results.violations.filter((v) => v.nodes.length > 0);
        const serious = results.violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
        for (const v of results.violations.filter((v) => !serious.includes(v))) {
          console.log(`${scheme} ${path}: ${v.impact} ${v.id}: ${v.help} (${v.nodes.length})`);
        }
        expect(
          serious.map((v) => `${v.impact} ${v.id}: ${v.help} (${v.nodes.length}): ${v.nodes[0]?.target}`),
        ).toEqual([]);
      });
    }
  });
}
