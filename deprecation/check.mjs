// Checks each deprecation image against its original, then runs them all on
// a kind cluster. A deprecation image may differ from its original only by
// the banner on the page, the notice on startup and its labels.
//
//   D1 The image config is the same: user, command, entrypoint, environment,
//      ports and working directory. The deprecation labels are set.
//   D2 The page, with the same settings, is the original page with the banner
//      added after <body>, and nothing else changed.
//   D3 The static files are byte for byte the same.
//   D4 The notice is in the logs, as are the original's own log lines, and
//      the app answers as soon as the original does.
//   K1 On kind, each image passes HTTP liveness and readiness probes on /,
//      and its pod log has the notice.
//
// Usage: deprecation/deprecate.sh test [tag...] (after build)
// Needs docker, kind, kubectl and curl. KEEP_CLUSTER=1 keeps the kind cluster.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { isDeepStrictEqual } from 'node:util';

const here = new URL('.', import.meta.url).pathname;
const repoImage = 'paulbouwer/hello-kubernetes';
const localImage = 'hello-kubernetes-deprecated';
const cluster = 'hk-deprecation';
const tags = process.argv.slice(2);
const digests = Object.fromEntries(
  readFileSync(join(here, 'tags.txt'), 'utf8')
    .split('\n')
    .filter((l) => l && !l.startsWith('#'))
    .map((l) => l.trim().split(/\s+/))
    .filter((f) => f.length === 3)
    .map(([tag, digest]) => [tag, digest]),
);

const run = (cmd, args, options = {}) =>
  execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options });
const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

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

// The banner as patch.js inserts it, for this tag.
const banner = (tag) =>
  readFileSync(join(here, 'banner.html'), 'utf8').replaceAll('{{tag}}', tag).replace(/\s*\n\s*/g, ' ').trim();

// Starts an image with the same settings as its twin, and waits for it to answer.
function start(image) {
  const id = run('docker', [
    'run', '-d', '--platform', 'linux/amd64', '--pull', 'never', '--hostname', 'hello-kubernetes-deprecation-test',
    '-e', 'MESSAGE=Hello from the deprecation test', '-p', '127.0.0.1::8080', image,
  ]).trim();
  const port = run('docker', ['port', id, '8080/tcp']).trim().split('\n')[0].split(':').pop();
  const started = Date.now();
  let ready = 0;
  for (let i = 0; i < 120 && !ready; i++) {
    try {
      run('curl', ['-fs', '-o', '/dev/null', `http://127.0.0.1:${port}/`]);
      ready = Date.now() - started;
    } catch {
      sleep(250);
    }
  }
  return { id, port, ready };
}
const get = (port, path) => execFileSync('curl', ['-fs', `http://127.0.0.1:${port}${path}`], { stdio: ['ignore', 'pipe', 'pipe'] });
const stop = (c) => run('docker', ['rm', '-f', c.id]);

for (const tag of tags) {
  const originalImage = `${repoImage}@${digests[tag]}`;
  const newImage = `${localImage}:${tag}`;
  run('docker', ['pull', '-q', '--platform', 'linux/amd64', originalImage]);

  // D1: the image config.
  const config = (image) => JSON.parse(run('docker', ['image', 'inspect', image, '--format', '{{json .Config}}']));
  const a = config(originalImage);
  const b = config(newImage);
  const d1 = [];
  for (const key of ['User', 'Cmd', 'Entrypoint', 'Env', 'ExposedPorts', 'WorkingDir', 'Volumes', 'StopSignal']) {
    if (!isDeepStrictEqual(a[key] ?? null, b[key] ?? null)) d1.push(`${key}: ${JSON.stringify(a[key])} became ${JSON.stringify(b[key])}`);
  }
  if (b.Labels?.['io.github.paulbouwer.hello-kubernetes.deprecated'] !== 'true') d1.push('the deprecated label is missing');
  result('D1', `${tag}: the image config is the original's`, d1);

  // D2 to D4: the original and the new image, side by side.
  const original = start(originalImage);
  const updated = start(newImage);
  try {
    const d2 = [];
    const before = original.ready ? get(original.port, '/').toString() : '';
    const after = updated.ready ? get(updated.port, '/').toString() : '';
    if (!before || !after) d2.push(`the page didn't load: original ${Boolean(before)}, new ${Boolean(after)}`);
    else if (!after.includes(banner(tag))) d2.push('the banner is not on the page');
    else if (after.replace(banner(tag), '') !== before) d2.push('the page differs from the original by more than the banner');
    else if (!/<body[^>]*><div id="hello-kubernetes-deprecated"/.test(after)) d2.push('the banner is not straight after <body>');
    result('D2', `${tag}: the page is the original's, with the banner`, d2);

    const d3 = [];
    const files = before.includes('css/main.css') ? ['/css/main.css', '/images/kubernetes.png'] : ['/images/hello-kubernetes.png'];
    for (const file of files) {
      try {
        if (!get(original.port, file).equals(get(updated.port, file))) d3.push(`${file} differs`);
      } catch {
        d3.push(`${file} didn't load`);
      }
    }
    result('D3', `${tag}: the static files are the original's`, d3);

    const d4 = [];
    const logs = (c) => run('docker', ['logs', c.id], { stdio: ['ignore', 'pipe', 'pipe'] });
    const beforeLogs = logs(original);
    const afterLogs = logs(updated);
    if (!afterLogs.includes(`DEPRECATED: hello-kubernetes ${tag} is unsupported`)) d4.push('the notice is not in the logs');
    // 1.10.x logs JSON with a time and a process ID, which differ between runs.
    const plain = (l) => l.trim().replace(/"time":\d+,"pid":\d+,/, '');
    const afterLines = afterLogs.split('\n').map(plain);
    for (const line of beforeLogs.split('\n').filter((l) => /listening/i.test(l))) {
      if (!afterLines.includes(plain(line))) d4.push(`the original's log line is missing: ${line.trim()}`);
    }
    if (updated.ready > original.ready + 3000) d4.push(`it answered after ${updated.ready} ms; the original after ${original.ready} ms`);
    result('D4', `${tag}: the notice is logged, and the app starts as quickly`, d4);
  } finally {
    stop(original);
    stop(updated);
  }
}

// K1: every image on kind, with probes.
if (tags.length) {
  const kubeconfig = join(mkdtempSync(join(tmpdir(), 'hk-deprecation-')), 'kubeconfig');
  const k = (...args) => run('kubectl', ['--kubeconfig', kubeconfig, ...args]);
  const exists = run('kind', ['get', 'clusters']).split('\n').includes(cluster);
  if (!exists) run('kind', ['create', 'cluster', '--name', cluster, '--kubeconfig', kubeconfig, '--wait', '120s']);
  else writeFileSync(kubeconfig, run('kind', ['get', 'kubeconfig', '--name', cluster]));
  try {
    for (const tag of tags) run('kind', ['load', 'docker-image', '--name', cluster, `${localImage}:${tag}`]);
    for (const tag of tags) {
      const name = `deprecated-${tag.replaceAll('.', '-')}`;
      const probe = { httpGet: { path: '/', port: 8080 }, periodSeconds: 2, failureThreshold: 3 };
      const manifest = {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: { name },
        spec: {
          replicas: 1,
          selector: { matchLabels: { app: name } },
          template: {
            metadata: { labels: { app: name } },
            spec: {
              containers: [
                {
                  name: 'hello-kubernetes',
                  image: `${localImage}:${tag}`,
                  imagePullPolicy: 'Never',
                  ports: [{ containerPort: 8080 }],
                  livenessProbe: probe,
                  readinessProbe: probe,
                },
              ],
            },
          },
        },
      };
      execFileSync('kubectl', ['--kubeconfig', kubeconfig, 'apply', '-f', '-'], { input: JSON.stringify(manifest), stdio: ['pipe', 'ignore', 'pipe'] });
    }
    for (const tag of tags) {
      const name = `deprecated-${tag.replaceAll('.', '-')}`;
      const k1 = [];
      try {
        k('rollout', 'status', `deployment/${name}`, '--timeout=180s');
        sleep(7000); // three liveness probes
        const pod = JSON.parse(k('get', 'pods', '-l', `app=${name}`, '-o', 'json')).items[0];
        const restarts = pod.status.containerStatuses[0].restartCount;
        if (restarts) k1.push(`the pod restarted ${restarts} times`);
        if (!k('logs', pod.metadata.name).includes(`DEPRECATED: hello-kubernetes ${tag}`)) k1.push('the notice is not in the pod log');
      } catch (error) {
        k1.push(String(error.stderr || error.message).trim().split('\n')[0]);
      }
      result('K1', `${tag}: runs on kind, and passes its probes`, k1);
    }
  } finally {
    if (process.env.KEEP_CLUSTER !== '1') run('kind', ['delete', 'cluster', '--name', cluster]);
    rmSync(join(kubeconfig, '..'), { recursive: true, force: true });
  }
}

if (failures) {
  console.log(`${failures} check(s) failed`);
  process.exit(1);
}
console.log(`All checks passed for ${tags.join(', ')}`);
