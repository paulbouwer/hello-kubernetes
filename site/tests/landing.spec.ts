// Checks the landing page: its commands are the quick start's, the chips
// change the command, the terminal and the preview together, the preview's
// assets load only when the mock-up comes into view, and the page carries its
// Open Graph image and structured data. The header has the Docs and Config
// builder links here only.
import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { landingChips } from '../src/lib/scenarios.mjs';

const base = '/hello-kubernetes/';
const repo = new URL('../../', import.meta.url).pathname;
const schema = JSON.parse(readFileSync(`${repo}deploy/helm/hello-kubernetes/values.schema.json`, 'utf8'));
const version = readFileSync(`${repo}deploy/helm/hello-kubernetes/Chart.yaml`, 'utf8').match(
  /^appVersion:\s*"?([^"\s]+)"?/m,
)![1];
const chips = landingChips(schema, version);

// The first line of the quick start's first block for a group, which E15 runs.
function quickStart(group: string) {
  const mdx = readFileSync(`${repo}site/src/content/docs/docs/start-here/quick-start.mdx`, 'utf8');
  return mdx.match(new RegExp('^```bash e2e=' + group + '\\n(.*)$', 'm'))![1];
}

test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

// Astro removes an island's ssr attribute once it has hydrated. Until then, a
// click does nothing, so each test waits for it before it uses the page.
test.beforeEach(async ({ page }) => {
  const goto = page.goto.bind(page);
  page.goto = async (url, options) => {
    const response = await goto(url, options);
    await expect(page.locator('astro-island[ssr]')).toHaveCount(0);
    return response;
  };
});

test('the commands are the quick start’s, and Copy leaves out the prompt', async ({ page }) => {
  await page.goto(base);
  const box = page.locator('.hk-land-install .hk-land-command code');
  await expect(box).toHaveText(quickStart('kubectl'));
  await page.locator('.hk-land-install .hk-land-copy').click();
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(quickStart('kubectl'));
  await page.getByRole('button', { name: 'Helm', exact: true }).click();
  await expect(box).toHaveText(quickStart('helm'));
  await expect(page.locator('.hk-land-closing code')).toHaveText(quickStart('kubectl'));
});

test('the preview’s assets load only when the mock-up comes into view', async ({ page }) => {
  const assets: string[] = [];
  page.on('request', (r) => {
    if (r.url().includes('preview-assets')) assets.push(r.url());
  });
  await page.setViewportSize({ width: 1440, height: 400 });
  await page.goto(base, { waitUntil: 'networkidle' });
  expect(assets).toEqual([]);
  await page.locator('.hk-land-mockup').scrollIntoViewIfNeeded();
  await expect(page.frameLocator('.hk-land-page iframe').locator('#message')).toHaveText('Hello world!');
  expect(assets).toHaveLength(1);
  await expect(page.locator('.hk-land-page iframe')).toHaveAttribute('sandbox', '');
});

test('each chip changes the command, the terminal and the preview together', async ({ page }) => {
  await page.goto(base);
  const app = page.frameLocator('.hk-land-page iframe');
  const box = page.locator('.hk-land-install .hk-land-command code');
  for (const chip of chips.filter((c) => c.id !== 'default')) {
    await page.getByRole('button', { name: chip.label }).click();
    await expect(box).toHaveText(chip.helm);
    await expect(page.locator('.hk-land-url')).toHaveText(chip.url);
    await expect(page.locator('.hk-land-terminal pre').first()).toHaveText(chip.terminal[0].output + '\n');
    await expect(app.locator('#message')).toHaveText(chip.message || 'Hello world!');
  }
  // kubectl can't set a chip's options in one command, so the page says how.
  await page.getByRole('button', { name: 'kubectl', exact: true }).click();
  await expect(page.locator('.hk-land-under')).toContainText('config builder');
});

test('reloading the preview shows another pod, highlighted in the terminal', async ({ page }) => {
  await page.goto(base);
  await page.getByRole('button', { name: '4 pods across nodes' }).click();
  const pod = page.frameLocator('.hk-land-page iframe').locator('#info tr:nth-child(2) td');
  await expect(pod).toHaveText(/hello-kubernetes-demo-/);
  const first = await pod.innerText();
  await expect(page.locator('.hk-land-answered')).toContainText(first);
  await page.getByRole('button', { name: 'Send another request' }).click();
  await expect(pod).not.toHaveText(first);
  await expect(page.locator('.hk-land-answered')).toContainText(await pod.innerText());
});

test('the page has one headline, its Open Graph image and its structured data', async ({ page, request }) => {
  await page.goto(base);
  await expect(page.locator('h1:visible')).toHaveCount(1);
  await expect(page.locator('h1:visible')).toContainText('Hello, Kubernetes.');
  const image = await page.locator('meta[property="og:image"]').getAttribute('content');
  const png = await request.get(new URL(image!).pathname);
  expect(png.status()).toBe(200);
  expect(png.headers()['content-type']).toBe('image/png');
  const data = JSON.parse((await page.locator('script[type="application/ld+json"]').textContent())!);
  expect(data['@type']).toBe('SoftwareApplication');
  expect(data.softwareVersion).toBe(version);
});

test('the header has Docs and Config builder on the landing page only', async ({ page }) => {
  await page.goto(base);
  const nav = page.getByRole('navigation', { name: 'Site' });
  await expect(nav.getByRole('link', { name: 'Docs' })).toBeVisible();
  await expect(nav.getByRole('link', { name: 'Config builder' })).toBeVisible();
  await page.goto(`${base}docs/start-here/overview/`);
  await expect(page.getByRole('navigation', { name: 'Site' })).toHaveCount(0);
});
