// Checks the docs for agents, written by scripts/build-markdown.mjs: llms.txt
// and every link in it, the Markdown copy of each docs page, llms-full.txt,
// the schema, and the copy button and hidden note on each docs page.
import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';

const site = 'https://paulbouwer.github.io';
const base = '/hello-kubernetes/';
const sitemap = readFileSync(new URL('../dist/sitemap-0.xml', import.meta.url), 'utf8');
const docs = [...sitemap.matchAll(/<loc>https:\/\/paulbouwer\.github\.io(\/hello-kubernetes\/docs\/[^<]*)<\/loc>/g)].map(
  (m) => m[1],
);
const version = readFileSync(new URL('../../deploy/helm/hello-kubernetes/Chart.yaml', import.meta.url), 'utf8').match(
  /^appVersion:\s*"?([^"\s]+)"?/m,
)![1];

// The Markdown with its code taken out, so only the prose is checked.
const prose = (markdown: string) => markdown.replace(/^```[\s\S]*?^```/gm, '').replace(/`[^`\n]*`/g, '');

test('llms.txt follows the llmstxt.org format, and lists every docs page', async ({ request }) => {
  const response = await request.get(`${base}llms.txt`);
  expect(response.status()).toBe(200);
  const llms = await response.text();
  expect(llms).toMatch(/^# hello-kubernetes\n\n> \S/);
  expect(llms).toContain(`hello-kubernetes ${version}, the latest release`);
  expect(llms).toContain('older releases are in the repo at their tag');
  expect(llms).toContain('Open only the pages you need');
  expect(llms).toContain(`${site}${base}values.schema.json`);
  expect(llms).toMatch(/^## Optional$/m);
  for (const path of docs) {
    expect(llms, `llms.txt has no entry for ${path}`).toContain(`(${site}${path.replace(/\/$/, '.md')})`);
  }
});

test('every link in llms.txt resolves', async ({ request }) => {
  const llms = await (await request.get(`${base}llms.txt`)).text();
  const links = [...llms.matchAll(/\]\((https:\/\/paulbouwer\.github\.io[^)]+)\)/g)].map((m) => m[1]);
  expect(links.length).toBeGreaterThan(docs.length);
  for (const link of links) {
    const response = await request.get(new URL(link).pathname);
    expect(response.status(), `${link} returned ${response.status()}`).toBe(200);
  }
});

test('each Markdown copy reads cleanly', async ({ request }) => {
  for (const path of docs) {
    const markdown = await (await request.get(path.replace(/\/$/, '.md'))).text();
    expect(markdown, path).toMatch(/^# \S.*\n\n> \S/);
    const html = prose(markdown).match(/<\/?[a-zA-Z][^>]*>|<!--/);
    expect(html?.[0], `${path} has HTML in its Markdown`).toBeUndefined();
    expect(prose(markdown), `${path} has component markup`).not.toMatch(/<CodeGroup|<Tabs|<TabItem|import \{/);
    expect(markdown, `${path} links to an HTML page instead of its Markdown`).not.toMatch(
      /\]\(https:\/\/paulbouwer\.github\.io\/hello-kubernetes\/docs\/[^)#]*\/(#[^)]*)?\)/,
    );
  }
});

test('a code group shows every tab, labelled, with its own code block', async ({ request }) => {
  const markdown = await (await request.get(`${base}docs/start-here/quick-start.md`)).text();
  expect(markdown).toMatch(/\*\*kubectl\*\*\n\n```bash\nkubectl apply/);
  expect(markdown).toMatch(/\*\*Helm\*\*\n\n```bash\nhelm install demo/);
});

test('llms-full.txt has every docs page, and the schema is served', async ({ request }) => {
  const full = await (await request.get(`${base}llms-full.txt`)).text();
  for (const path of docs) {
    const markdown = await (await request.get(path.replace(/\/$/, '.md'))).text();
    expect(full, `llms-full.txt is missing ${path}`).toContain(markdown.split('\n')[0]);
  }
  const schema = await (await request.get(`${base}values.schema.json`)).json();
  expect(schema.properties.pathPrefix).toBeDefined();
});

test.describe('each docs page', () => {
  test.use({ permissions: ['clipboard-read', 'clipboard-write'] });

  for (const path of docs) {
    test(`${path} has the copy button and the hidden note`, async ({ page }) => {
      await page.goto(path);
      const note = page.locator('[data-agent-note]');
      await expect(note).toBeHidden();
      await expect(note).toContainText(`${site}${path.replace(/\/$/, '.md')}`);
      await expect(note).toContainText(`${site}${base}llms.txt`);
      await page.getByRole('button', { name: 'Copy page as Markdown' }).click();
      await expect(page.getByRole('status').filter({ hasText: 'Copied' })).toBeVisible();
      const copied = await page.evaluate(() => navigator.clipboard.readText());
      expect(copied.split('\n')[0]).toBe(`# ${await page.locator('h1#_top').innerText()}`);
    });
  }
});
