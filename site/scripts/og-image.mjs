// Draws the Open Graph image, public/og.png (1200 by 630): the wordmark, the
// headline, and the app's page as the live preview renders it. The PNG is
// committed; run this again when the look or the app's page changes.
//
// Usage: make og-image (runs this in the pinned Playwright image)
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { chromium } from '@playwright/test';
import * as preview from '../src/lib/preview.mjs';

const require = createRequire(import.meta.url);
const root = new URL('../../', import.meta.url).pathname;
const out = new URL('../public/og.png', import.meta.url).pathname;
const app = `${root}src/app/`;
const version = readFileSync(`${root}deploy/helm/hello-kubernetes/Chart.yaml`, 'utf8').match(
  /^appVersion:\s*"?([^"\s]+)"?/m,
)[1];

const dataUrl = (file, type) => `data:${type};base64,${readFileSync(file).toString('base64')}`;
const font = (pkg, file) => dataUrl(join(dirname(require.resolve(`${pkg}/package.json`)), 'files', file), 'font/woff2');

// The app's page, as the preview renders it, with its assets inlined.
const fonts = {};
for (const subset of ['cyrillic-ext', 'cyrillic', 'greek-ext', 'greek', 'latin-ext', 'latin']) {
  const file = `ubuntu-${subset}-300-normal.woff2`;
  fonts[file] = dataUrl(`${app}static/fonts/ubuntu/${file}`, 'font/woff2');
}
const render = preview.createRenderer({
  layout: readFileSync(`${app}views/layouts/main.handlebars`, 'utf8'),
  home: readFileSync(`${app}views/home.handlebars`, 'utf8'),
});
const page = preview.inlineAssets(
  render(
    preview.pageContext({
      KUBERNETES_NAMESPACE: 'default',
      KUBERNETES_POD_NAME: preview.podName('demo', 0),
      KUBERNETES_NODE_NAME: preview.nodeName(0),
      CONTAINER_IMAGE: `paulbouwer/hello-kubernetes:${version}`,
      nodeOS: 'Linux 6.8.0',
      arch: 'linux/amd64',
    }),
  ),
  { css: readFileSync(`${app}static/css/main.css`, 'utf8'), fonts, logo: dataUrl(`${app}static/images/kubernetes.png`, 'image/png') },
);

const escape = (html) => html.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
const card = `<!doctype html>
<html><head><style>
  @font-face { font-family: Archivo; font-weight: 700; src: url(${font('@fontsource/archivo', 'archivo-latin-700-normal.woff2')}); }
  @font-face { font-family: Inter; font-weight: 400; src: url(${font('@fontsource/inter', 'inter-latin-400-normal.woff2')}); }
  @font-face { font-family: 'JetBrains Mono'; font-weight: 600; src: url(${font('@fontsource/jetbrains-mono', 'jetbrains-mono-latin-600-normal.woff2')}); }
  * { box-sizing: border-box; margin: 0; }
  body { width: 1200px; height: 630px; overflow: hidden; background: #17181c; color: #fff;
    display: grid; grid-template-columns: 520px 1fr; align-items: center; gap: 40px; padding: 0 0 0 64px; }
  .mark { font: 600 30px 'JetBrains Mono'; letter-spacing: -0.01em; }
  h1 { margin: 36px 0 24px; font: 700 54px/1.08 Archivo; letter-spacing: -0.02em; }
  h1 span { display: block; color: #8b8e98; }
  p { font: 400 24px/1.45 Inter; color: #c4c6cc; }
  .bar { display: flex; gap: 8px; align-items: center; height: 40px; padding: 0 16px; background: #1b2433;
    border: 1px solid #2a3f6b; border-bottom: 0; border-radius: 12px 0 0 0; }
  .bar i { width: 12px; height: 12px; border-radius: 50%; background: #4a4d55; }
  .frame { border: 1px solid #2a3f6b; border-right: 0; overflow: hidden; height: 450px; }
  iframe { display: block; border: 0; width: 800px; height: 600px; transform: scale(0.75); transform-origin: 0 0; }
</style></head><body>
  <div>
    <div class="mark">hello-kubernetes</div>
    <h1>Hello, Kubernetes. <span>See which pod answered.</span></h1>
    <p>A small web app to deploy on your cluster. It shows the namespace, pod and node that answered.</p>
  </div>
  <div><div class="bar"><i></i><i></i><i></i></div><div class="frame"><iframe sandbox srcdoc="${escape(page)}"></iframe></div></div>
</body></html>`;

const browser = await chromium.launch();
const tab = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await tab.setContent(card, { waitUntil: 'load' });
await tab.evaluate(() => document.fonts.ready);
await tab.waitForTimeout(500);
await tab.screenshot({ path: out });
await browser.close();
console.log(`Wrote ${out}`);
