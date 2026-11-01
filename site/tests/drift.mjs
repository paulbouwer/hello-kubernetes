// Drift tests for the config builder and the live preview. They run the same
// code the page runs (src/lib/preview.mjs and src/lib/builder.mjs):
//
//   S1 The preview renders the same HTML as the app's container, for the same
//      settings: the defaults, a message with HTML in it, and a path prefix.
//   S2 For each set of options, helm template accepts the builder's --set
//      flags and its values.yaml, both render the same, and the result has
//      what was chosen.
//   S3 For each set of options, kubectl kustomize on the builder's Kustomize
//      output, with the release file rendered here, matches helm template
//      with the release name demo. Only the namespace field, the Namespace
//      object and the order of env vars may differ.
//
// Usage: make site-drift (builds the image, then runs this from site/)
// Environment: IMAGE, the app image to test (default hello-kubernetes:drift).
// Needs docker, helm and kubectl.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { isDeepStrictEqual } from 'node:util';
import { parseAllDocuments } from 'yaml';
import * as builder from '../src/lib/builder.mjs';
import * as preview from '../src/lib/preview.mjs';

const root = new URL('../../', import.meta.url).pathname;
const chart = `${root}deploy/helm/hello-kubernetes`;
const schema = JSON.parse(readFileSync(`${chart}/values.schema.json`, 'utf8'));
const version = readFileSync(`${chart}/Chart.yaml`, 'utf8').match(/^appVersion:\s*"?([^"\s]+)"?/m)[1];
const image = process.env.IMAGE || 'hello-kubernetes:drift';
const work = mkdtempSync(join(tmpdir(), 'hk-drift-'));

let failures = 0;
function result(id, name, problems) {
  if (problems.length) {
    failures++;
    console.log(`FAIL ${id} ${name}`);
    for (const p of problems) console.log(`    ${p}`);
  } else {
    console.log(`PASS ${id} ${name}`);
  }
}
const run = (cmd, args, options = {}) => execFileSync(cmd, args, { encoding: 'utf8', ...options });

// The first place where two objects differ, as a path such as
// spec.template.spec.containers.0.livenessProbe.httpGet.path.
function firstChange(a, b, path = '') {
  if (isDeepStrictEqual(a, b)) return '';
  if (a && b && typeof a === 'object' && typeof b === 'object') {
    for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
      const found = firstChange(a[key], b[key], path ? `${path}.${key}` : key);
      if (found) return found;
    }
  }
  return `${path}: helm ${JSON.stringify(a)}, kustomize ${JSON.stringify(b)}`;
}

// The first line where two texts differ, to show in a failure.
function firstDifference(a, b) {
  const x = a.split('\n');
  const y = b.split('\n');
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if (x[i] !== y[i]) return `line ${i + 1}: app ${JSON.stringify(x[i])}, preview ${JSON.stringify(y[i])}`;
  }
  return '';
}

// S1: the preview and the app.
const render = preview.createRenderer({
  layout: readFileSync(`${root}src/app/views/layouts/main.handlebars`, 'utf8'),
  home: readFileSync(`${root}src/app/views/home.handlebars`, 'utf8'),
});
const pages = [
  { name: 'the defaults', env: {} },
  { name: 'a message with HTML in it', env: { MESSAGE: `<b>Hi</b> & "you" <script>alert(1)</script>` } },
  {
    name: 'a path prefix',
    env: { MESSAGE: 'Under a prefix', HANDLER_PATH_PREFIX: 'app/hello/', RENDER_PATH_PREFIX: '/app/hello' },
  },
];
for (const page of pages) {
  const env = {
    KUBERNETES_NAMESPACE: 'drift-test',
    KUBERNETES_POD_NAME: preview.podName('drift', 0),
    KUBERNETES_NODE_NAME: preview.nodeName(0),
    CONTAINER_IMAGE: `paulbouwer/hello-kubernetes:${version}`,
    ...page.env,
  };
  const problems = [];
  const args = ['run', '-d', '--pull', 'never', '-p', '127.0.0.1::8080'];
  for (const [k, v] of Object.entries(env)) args.push('-e', `${k}=${v}`);
  const id = run('docker', [...args, image]).trim();
  try {
    const port = run('docker', ['port', id, '8080/tcp']).trim().split('\n')[0].split(':').pop();
    const machine = JSON.parse(
      run('docker', [
        'exec',
        id,
        'node',
        '-e',
        `const os = require('os'); const a = { x64: 'amd64', ia32: '386', ppc64: 'ppc64le' };
         console.log(JSON.stringify({ nodeOS: os.type() + ' ' + os.release(), arch: process.platform + '/' + (a[process.arch] || process.arch) }))`,
      ]),
    );
    const path = preview.normalisePrefix(env.HANDLER_PATH_PREFIX) + '/';
    let app = '';
    for (let i = 0; i < 40 && !app; i++) {
      try {
        app = run('curl', ['-fs', `http://127.0.0.1:${port}${path}`]);
      } catch {
        run('sleep', ['0.25']);
      }
    }
    const html = render(preview.pageContext({ ...env, ...machine }));
    if (!app) problems.push(`the app didn't answer at ${path}`);
    else if (app !== html) problems.push(firstDifference(app, html));
  } finally {
    run('docker', ['rm', '-f', id]);
  }
  result('S1', `the preview matches the app: ${page.name}`, problems);
}

// The sets of options for S2 and S3.
const base = builder.defaultOptions(schema);
const cases = [
  { name: 'the defaults' },
  { name: 'a message, replicas and a NodePort', message: `It's "quoted" & <b>bold</b>`, replicas: 3, serviceType: 'NodePort', servicePort: 8080 },
  { name: 'an Ingress, no rewriting', expose: 'ingress', serviceType: 'ClusterIP', ingressClass: 'traefik', ingressHost: 'hello.example.com', pathPrefix: '/app/hello' },
  { name: 'an Ingress with rewriting', expose: 'ingress', serviceType: 'ClusterIP', ingressClass: 'nginx', pathPrefix: 'app/hello/', rewritePath: true },
  { name: 'a Gateway with rewriting', expose: 'gateway', serviceType: 'ClusterIP', servicePort: 8080, gatewayName: 'shared', gatewayNamespace: 'gateway-system', hostname: 'hello.example.com', pathPrefix: '/app/hello', rewritePath: true },
  { name: 'a Gateway, GHCR and a tag', expose: 'gateway', gatewayName: 'my-gateway', registry: 'ghcr', tag: '1.11' },
  { name: 'your own proxy, no rewriting', pathPrefix: '/app/hello', replicas: 1 },
  { name: 'the default namespace, GHCR', namespace: 'default', registry: 'ghcr', replicas: 0 },
];

const documents = (text) =>
  parseAllDocuments(text)
    .map((d) => d.toJS())
    .filter(Boolean);
const find = (docs, kind) => docs.find((d) => d.kind === kind);

// The local chart in place of the published one, without --wait.
const local = (cmd) =>
  cmd
    .replace(builder.chartRef, chart)
    .replace(/--version \S+ /, '')
    .replace(/ \\\n {2}--create-namespace/, '');

for (const c of cases) {
  const o = { ...base, ...c };
  const problems = [];
  // S2: --set and values.yaml render the same, with what was chosen.
  const withFlags = run('bash', ['-c', local(builder.helmTemplate(o, schema, version))]);
  writeFileSync(join(work, 'values.yaml'), builder.valuesYaml(o, schema));
  const withFile = run('helm', ['template', o.release, chart, '--namespace', o.namespace, '--values', join(work, 'values.yaml')]);
  if (withFlags !== withFile) problems.push('--set and values.yaml render differently');
  const docs = documents(withFlags);
  const deployment = find(docs, 'Deployment');
  const container = deployment.spec.template.spec.containers[0];
  const env = Object.fromEntries(container.env.map((e) => [e.name, e.value]));
  const service = find(docs, 'Service');
  const expectImage = `${builder.repositories[o.registry]}:${o.tag || version}`;
  if (deployment.spec.replicas !== Number(o.replicas)) problems.push(`replicas ${deployment.spec.replicas}`);
  if ((env.MESSAGE ?? '') !== o.message) problems.push(`MESSAGE ${JSON.stringify(env.MESSAGE)}`);
  if (container.image !== expectImage) problems.push(`image ${container.image}`);
  if (service.spec.type !== o.serviceType) problems.push(`Service type ${service.spec.type}`);
  if (service.spec.ports[0].port !== Number(o.servicePort)) problems.push(`Service port ${service.spec.ports[0].port}`);
  const ingress = find(docs, 'Ingress');
  if ((o.expose === 'ingress') !== Boolean(ingress)) problems.push(`Ingress ${ingress ? 'present' : 'missing'}`);
  if (ingress && (ingress.spec.ingressClassName || '') !== o.ingressClass) problems.push('Ingress class');
  if (ingress && (ingress.spec.rules[0].host || '') !== o.ingressHost) problems.push('Ingress host');
  const route = find(docs, 'HTTPRoute');
  if ((o.expose === 'gateway') !== Boolean(route)) problems.push(`HTTPRoute ${route ? 'present' : 'missing'}`);
  if (route && route.spec.parentRefs[0].name !== (o.gatewayName || 'my-gateway')) problems.push('HTTPRoute parent');
  const prefix = preview.normalisePrefix(o.pathPrefix);
  if ((env.RENDER_PATH_PREFIX ?? '') !== prefix) problems.push(`RENDER_PATH_PREFIX ${env.RENDER_PATH_PREFIX}`);
  result('S2', `helm template gives what was chosen: ${c.name}`, problems);

  // S3: Kustomize on the release file matches helm template.
  const s3 = [];
  const dir = mkdtempSync(join(work, 'kustomize-'));
  writeFileSync(join(dir, 'hello-kubernetes.yaml'), run('helm', ['template', 'demo', chart]));
  for (const [file, content] of Object.entries(builder.kustomize(o, schema, version))) {
    writeFileSync(
      join(dir, file),
      content.replace(/https:\/\/github\.com\/paulbouwer\/hello-kubernetes\/releases\/download\/[^\s]+\/hello-kubernetes\.yaml/, 'hello-kubernetes.yaml'),
    );
  }
  let kustomized = '';
  try {
    kustomized = run('kubectl', ['kustomize', dir], { stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (error) {
    s3.push(`kubectl kustomize failed: ${String(error.stderr).trim().split('\n')[0]}`);
  }
  if (kustomized) {
    const helm = run('bash', ['-c', local(builder.helmTemplate({ ...o, release: 'demo' }, schema, version))]);
    const normalise = (text) => {
      const byName = {};
      for (const d of documents(text)) {
        if (d.kind === 'Namespace') continue;
        delete d.metadata.namespace;
        for (const container of d.spec?.template?.spec?.containers || []) {
          container.env?.sort((a, b) => a.name.localeCompare(b.name));
        }
        byName[`${d.kind}/${d.metadata.name}`] = d;
      }
      return byName;
    };
    const a = normalise(helm);
    const b = normalise(kustomized);
    for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
      if (!a[key]) s3.push(`only in Kustomize: ${key}`);
      else if (!b[key]) s3.push(`only in helm template: ${key}`);
      else if (!isDeepStrictEqual(a[key], b[key])) {
        s3.push(`${key} differs at ${firstChange(a[key], b[key])}`);
      }
    }
  }
  result('S3', `Kustomize matches helm template: ${c.name}`, s3);
}

rmSync(work, { recursive: true, force: true });
if (failures) {
  console.log(`${failures} drift test(s) failed`);
  process.exit(1);
}
console.log('All drift tests passed');
