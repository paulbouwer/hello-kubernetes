// Checks the config builder in a browser: the preview follows the options,
// stays sandboxed and makes no requests, and the output and its copy buttons
// follow the options too. The drift tests (tests/drift.mjs) check the output
// against the chart, and the preview against the app.
import { test, expect } from '@playwright/test';

const path = '/hello-kubernetes/docs/configure/builder/';

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

test('the preview follows the options, in an empty sandbox, with no requests', async ({ page }) => {
  await page.goto(path, { waitUntil: 'networkidle' });
  const requests: string[] = [];
  page.on('request', (request) => requests.push(request.url()));

  const frame = page.locator('.hk-browser-page iframe');
  await expect(frame).toHaveAttribute('sandbox', '');
  const app = page.frameLocator('.hk-browser-page iframe');
  await expect(app.locator('#message')).toHaveText('Hello world!');

  await page.fill('#hk-message', '<b>Bold</b> & <script>alert(1)</script>');
  await expect(app.locator('#message')).toHaveText('<b>Bold</b> & <script>alert(1)</script>');
  await expect(app.locator('#message b')).toHaveCount(0);

  await page.fill('#hk-namespace', 'demo-space');
  await page.selectOption('#hk-registry', 'ghcr');
  await page.fill('#hk-tag', '1.11');
  await page.selectOption('select[aria-label="Node architecture"]', 'linux/arm64');
  await expect(app.locator('#info')).toContainText('demo-space');
  await expect(app.locator('#footer')).toHaveText('ghcr.io/paulbouwer/hello-kubernetes:1.11 (linux/arm64)');

  // The logo and the font are inlined, so the frame loads them from data: URLs.
  await expect(app.locator('img')).toHaveAttribute('src', /^data:image\/png;base64,/);
  expect(requests).toEqual([]);
});

test('"Send another request" shows another pod, with more than one replica', async ({ page }) => {
  await page.goto(path);
  const app = page.frameLocator('.hk-browser-page iframe');
  const pod = () => app.locator('#info tr:nth-child(2) td').innerText();
  const first = await pod();
  await page.getByRole('button', { name: 'Send another request' }).click();
  await expect.poll(pod).not.toBe(first);

  await page.fill('#hk-replicas', '1');
  await expect(page.getByRole('button', { name: 'Send another request' })).toBeDisabled();
  await page.fill('#hk-replicas', '0');
  await expect(page.locator('.hk-browser-page')).toContainText('no pod answers');
});

test('the output follows the options, and each copy button copies it', async ({ page }) => {
  await page.goto(path);
  await page.check('input[name="hk-expose"][value="ingress"]');
  await expect(page.locator('#hk-service-type')).toHaveValue('ClusterIP');
  await page.fill('#hk-ingress-class', 'traefik');
  await page.fill('#hk-prefix', '/app/hello');

  const panel = page.locator('#hk-panel');
  await expect(panel).toContainText('--set ingress.enabled=true');
  await expect(panel).toContainText('--set rewritePath=false');

  await page.getByRole('tab', { name: 'values.yaml' }).click();
  await expect(panel).toContainText('className: traefik');

  await page.getByRole('tab', { name: 'Kustomize' }).click();
  await expect(panel.locator('.hk-file-header')).toHaveText(['kustomization.yaml', 'namespace.yaml', 'ingress.yaml']);
  await page.getByRole('button', { name: 'Copy ingress.yaml' }).click();
  const copied = await page.evaluate(() => navigator.clipboard.readText());
  expect(copied).toContain('kind: Ingress');
  expect(copied).toContain('path: /app/hello');

  // The tabs follow the arrow keys.
  await page.getByRole('tab', { name: 'Kustomize' }).press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'helm template' })).toBeFocused();
  await expect(panel).toContainText('helm template hello');
});

test('the builder notes the settings that need care', async ({ page }) => {
  await page.goto(path);
  await page.check('input[name="hk-expose"][value="ingress"]');
  await page.selectOption('#hk-service-type', 'LoadBalancer');
  await expect(page.locator('.hk-notes')).toContainText('set the Service type to ClusterIP');
  await page.check('input[name="hk-expose"][value="gateway"]');
  await expect(page.locator('.hk-notes')).toContainText('Name your Gateway');
});

test('the preview’s address follows the host, the port and the path prefix', async ({ page }) => {
  await page.goto(path);
  const url = page.locator('.hk-browser-url');
  await expect(url).toHaveText('http://hello.example.com/');
  await page.fill('#hk-service-port', '8080');
  await expect(url).toHaveText('http://hello.example.com:8080/');
  await page.check('input[name="hk-expose"][value="ingress"]');
  await page.fill('#hk-ingress-host', 'hello.my-cluster.test');
  await page.fill('#hk-prefix', 'app/hello/');
  await expect(url).toHaveText('http://hello.my-cluster.test/app/hello/');
  await page.check('input[name="hk-expose"][value="gateway"]');
  await expect(url).toHaveText('http://hello.example.com/app/hello/');
  await page.fill('#hk-hostname', 'gw.my-cluster.test');
  await expect(url).toHaveText('http://gw.my-cluster.test/app/hello/');
});
