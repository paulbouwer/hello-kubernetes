// The live preview's page: the app's own Handlebars templates, rendered with a
// context built the way src/app/server.js builds it. The drift test
// (test/site/drift.mjs) renders the same settings through this code and
// through the app's container, and the HTML must match.
//
// Plain JavaScript, so the test runs it in Node as it is.
import Handlebars from 'handlebars';

// As normalisePrefix in server.js: "app" or "/app/" becomes "/app", and an
// empty prefix, or one that is only slashes, becomes "".
export function normalisePrefix(value) {
  const path = (value || '').replace(/^[\\/]+/, '').replace(/[\\/]+$/, '');
  return path ? '/' + path : '';
}

// The context for home.handlebars and the layout, as server.js builds it.
//   settings: the environment the app would see (MESSAGE, KUBERNETES_*,
//             CONTAINER_IMAGE, RENDER_PATH_PREFIX), plus nodeOS and arch,
//             which the app reads from the machine it runs on.
export function pageContext(settings) {
  const renderPathPrefix = normalisePrefix(settings.RENDER_PATH_PREFIX);
  return {
    message: settings.MESSAGE || 'Hello world!',
    namespace: settings.KUBERNETES_NAMESPACE || '-',
    pod: settings.KUBERNETES_POD_NAME,
    node: (settings.KUBERNETES_NODE_NAME || '-') + ' (' + settings.nodeOS + ')',
    container: settings.CONTAINER_IMAGE + ' (' + settings.arch + ')',
    assetPathPrefix: renderPathPrefix ? renderPathPrefix + '/' : '',
  };
}

// Compiles the templates once. As express-handlebars does, it trims each
// template before compiling it and each result after rendering it, and renders
// the view, then the layout with the view as {{{body}}}.
export function createRenderer({ layout, home }) {
  const handlebars = Handlebars.create();
  const layoutTemplate = handlebars.compile(layout.trim());
  const homeTemplate = handlebars.compile(home.trim());
  return (context) => layoutTemplate({ ...context, body: homeTemplate(context).trim() }).trim();
}

// The page as the preview shows it: the stylesheet and the logo inlined, so
// the sandboxed frame makes no requests.
//   assets: { css, fonts: { 'ubuntu-latin-300-normal.woff2': dataUrl, ... }, logo: dataUrl }
export function inlineAssets(html, assets) {
  const css = assets.css.replace(/url\('\.\.\/fonts\/ubuntu\/([^']+)'\)/g, (match, file) =>
    assets.fonts[file] ? `url('${assets.fonts[file]}')` : match,
  );
  return html
    .replace(/<link rel="stylesheet" type="text\/css" href="[^"]*css\/main\.css">/, () => `<style>${css}</style>`)
    .replace(/<img src="[^"]*images\/kubernetes\.png"\/>/, () => `<img src="${assets.logo}" alt=""/>`);
}

// Realistic names for the preview: a pod name as a Deployment makes them,
// and a node for each pod.
const letters = 'bcdfghjklmnpqrstvwxz2456789';
function pick(seed, length) {
  let value = '';
  let n = seed;
  for (let i = 0; i < length; i++) {
    n = (n * 1103515245 + 12345) % 2147483648;
    value += letters[n % letters.length];
  }
  return value;
}

export function podName(release, index) {
  return `hello-kubernetes-${release}-${pick(7, 10)}-${pick(index + 11, 5)}`;
}

export function nodeName(index) {
  return `worker-${(index % 3) + 1}`;
}
