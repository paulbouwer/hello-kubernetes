// Writes the docs for agents into the built site, after astro build:
//   - a Markdown copy of each docs page, next to it: /docs/deploy/helm/ has
//     /docs/deploy/helm.md
//   - llms.txt, an index of those copies in the llmstxt.org format, in the
//     sidebar's order
//   - llms-full.txt, every page in one file
//   - values.schema.json, the chart's schema
// The Markdown comes from the built HTML, not the MDX, so code groups, file
// names and output blocks read as plain Markdown (.project/roadmap/1.x/site.md).
import { copyFileSync, readFileSync, writeFileSync } from 'node:fs';
import { select, selectAll } from 'hast-util-select';
import rehypeParse from 'rehype-parse';
import rehypeRemark from 'rehype-remark';
import remarkGfm from 'remark-gfm';
import remarkStringify from 'remark-stringify';
import { unified } from 'unified';

// The same as site and base in astro.config.mjs.
const site = 'https://paulbouwer.github.io';
const base = '/hello-kubernetes/';
const repo = 'https://github.com/paulbouwer/hello-kubernetes';

const root = new URL('../../', import.meta.url).pathname;
const dist = new URL('../dist/', import.meta.url).pathname;
const chart = `${root}deploy/helm/hello-kubernetes/`;
const version = readFileSync(`${chart}Chart.yaml`, 'utf8').match(/^appVersion:\s*"?([^"\s]+)"?/m)[1];

const parseHtml = (file) => unified().use(rehypeParse).parse(readFileSync(file, 'utf8'));
const htmlFile = (path) => `${dist}${path.slice(base.length)}index.html`;
const mdPath = (path) => path.replace(/\/$/, '.md');
const absolute = (path) => new URL(path, site).href;

function text(node) {
  if (node.type === 'text') return node.value;
  return (node.children || []).map(text).join('');
}

const el = (tagName, children, properties = {}) => ({ type: 'element', tagName, properties, children });
const t = (value) => ({ type: 'text', value });

// Rewrites the page content, in place, into HTML that converts cleanly.
function simplify(tree) {
  for (const node of selectAll(
    '.sl-anchor-link, .copy, script, style, svg, starlight-tabs-restore, [data-agent-note]',
    tree,
  )) {
    node.type = 'text';
    node.value = '';
    delete node.children;
  }
  // An interactive island, such as the config builder, becomes a note: its
  // form and its default output read as noise in Markdown.
  for (const island of selectAll('astro-island', tree)) {
    island.tagName = 'p';
    island.properties = {};
    island.children = [
      t(
        'This page has an interactive tool that works only in a browser. An agent can build the same output from the Values reference and values.schema.json, listed in llms.txt.',
      ),
    ];
  }
  // Comments, such as the ones Astro leaves, are dropped.
  (function dropComments(node) {
    if (!node.children) return;
    node.children = node.children.filter((child) => child.type !== 'comment');
    node.children.forEach(dropComments);
  })(tree);
  // A code block: its title (a file name, or "Terminal"), and its lines.
  for (const block of selectAll('.expressive-code', tree)) {
    const figure = select('figure', block);
    const title = text(select('.title', block) || t('')).trim();
    const lines = selectAll('.ec-line', block).map((line) => text(line));
    const language = select('pre', block)?.properties.dataLanguage || '';
    const output = figure?.properties.className?.includes('output');
    const label = output ? 'Output:' : title && title !== 'Terminal' ? `File: ${title}` : '';
    const code = el('pre', [el('code', [t(lines.join('\n'))], { className: [`language-${language}`] })]);
    block.tagName = 'div';
    block.properties = {};
    block.children = label ? [el('p', [el('em', [t(label)])]), code] : [code];
  }
  // A code group: each tab's label, then its content.
  for (const tabs of selectAll('starlight-tabs', tree)) {
    const labels = selectAll('[role="tab"]', tabs).map((tab) => text(tab).trim());
    const panels = selectAll('[role="tabpanel"]', tabs);
    tabs.tagName = 'div';
    tabs.children = panels.flatMap((panel, i) => [el('p', [el('strong', [t(labels[i])])]), ...panel.children]);
  }
  // Links to other pages point to their Markdown copies.
  for (const link of selectAll('a[href]', tree)) {
    const href = String(link.properties.href);
    if (href.startsWith(`${base}docs/`)) {
      const [path, anchor] = href.split('#');
      link.properties.href = absolute(mdPath(path)) + (anchor ? `#${anchor}` : '');
    } else if (href.startsWith(base)) {
      link.properties.href = absolute(href);
    }
  }
}

function toMarkdown(path) {
  const page = parseHtml(htmlFile(path));
  const title = text(select('h1#_top', page)).trim();
  const description = select('meta[name="description"]', page)?.properties.content || '';
  const content = select('main .sl-markdown-content', page);
  simplify(content);
  const mdast = unified().use(rehypeRemark).runSync({ type: 'root', children: [content] });
  const body = unified()
    .use(remarkGfm, { tablePipeAlign: false })
    .use(remarkStringify, { bullet: '-', fences: true, rule: '-' })
    .stringify(mdast);
  return { title, description, markdown: `# ${title}\n\n> ${description}\n\n${body.trim()}\n` };
}

// The docs pages, grouped and ordered as in the sidebar.
const sidebar = select('nav[aria-label="Main"] ul.top-level', parseHtml(htmlFile(`${base}docs/start-here/overview/`)));
const groups = [];
const others = [];
for (const item of sidebar.children.filter((n) => n.tagName === 'li')) {
  const label = select('.group-label', item);
  const links = selectAll('a[href]', item).map((a) => String(a.properties.href));
  if (label) groups.push({ name: text(label).trim(), links });
  else others.push(...links);
}

const pages = new Map();
for (const path of [...groups.flatMap((g) => g.links), ...others]) {
  const page = toMarkdown(path);
  writeFileSync(`${dist}${mdPath(path).slice(base.length)}`, page.markdown);
  pages.set(path, page);
}

copyFileSync(`${chart}values.schema.json`, `${dist}values.schema.json`);

const entry = (path) => `- [${pages.get(path).title}](${absolute(mdPath(path))}): ${pages.get(path).description}`;
const llms = [
  '# hello-kubernetes',
  '> A small web app to deploy on a Kubernetes cluster. Its page shows the message, and the namespace, pod and node that answered. It comes as a container image, a Helm chart and a release file.',
  `These are the docs for hello-kubernetes ${version}, the latest release. The docs for older releases are in the repo at their tag, for example ${repo}/tree/v1.10.1.`,
  'Each link below is a Markdown copy of one page. Open only the pages you need for your task, and come back to this index to find others. To deploy or configure hello-kubernetes, start with the Quick start or a Deploy page, and check chart values against the Values reference or the schema.',
  ...groups.flatMap((g) => [
    `## ${g.name}`,
    [
      ...g.links.map(entry),
      ...(g.name === 'Configure'
        ? [`- [values.schema.json](${absolute(`${base}values.schema.json`)}): the JSON Schema that Helm checks every chart value against`]
        : []),
    ].join('\n'),
  ]),
  '## Optional',
  [
    `- [All the docs in one file](${absolute(`${base}llms-full.txt`)}): every page above, in order`,
    ...others.map(entry),
  ].join('\n'),
].join('\n\n');
writeFileSync(`${dist}llms.txt`, `${llms}\n`);

const full = [...pages.values()].map((p) => p.markdown).join('\n---\n\n');
writeFileSync(`${dist}llms-full.txt`, full);

console.log(`Wrote llms.txt, llms-full.txt, values.schema.json and ${pages.size} Markdown pages.`);
