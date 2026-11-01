// The landing page's "Try one:" chips. Each is a set of config builder
// options. The Default chip shows the quick start's commands, which E15 runs;
// the others show the builder's Helm command, which the drift tests check
// (tests/drift.mjs runs every scenario here through S2 and S3).
//
// Plain JavaScript, so the drift test runs it in Node as it is.
import { defaultOptions, helmInstall } from './builder.mjs';
import { nodeName, podName } from './pods.mjs';

// The quick start's commands (site/src/content/docs/docs/start-here/quick-start.mdx).
// tests/landing.spec.ts checks that they stay the same.
export const quickStart = {
  kubectl:
    'kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml',
  helm: 'helm install demo oci://ghcr.io/paulbouwer/charts/hello-kubernetes --wait',
};

// The options for each chip, on top of the builder's defaults. The URLs use
// example.com, which is reserved for documentation.
const chips = [
  { id: 'default', label: 'Default', options: {}, url: 'http://hello.example.com/' },
  {
    id: 'message',
    label: 'Your message',
    options: { message: 'Hello from my cluster!' },
    url: 'http://hello.example.com/',
  },
  {
    id: 'ingress',
    label: 'Behind an Ingress',
    options: {
      expose: 'ingress',
      serviceType: 'ClusterIP',
      ingressClass: 'traefik',
      pathPrefix: '/app/hello',
      rewritePath: false,
    },
    url: 'http://hello.example.com/app/hello/',
  },
  {
    id: 'spread',
    label: '4 pods across nodes',
    options: { replicas: 4 },
    url: 'http://hello.example.com/',
  },
];

// The chips, with the builder's full options for each. The release is demo,
// in the default namespace, as in the quick start.
export function scenarios(schema) {
  return chips.map((chip) => ({
    ...chip,
    options: { ...defaultOptions(schema), release: 'demo', namespace: 'default', ...chip.options },
  }));
}

// What kubectl would print for a chip's pods, with the node each runs on, and
// its Ingress.
export function terminal(options) {
  const replicas = Number(options.replicas);
  const rows = [['NAME', 'STATUS', 'NODE']];
  for (let i = 0; i < replicas; i++) rows.push([podName('demo', i), 'Running', nodeName(i)]);
  const widths = rows[0].map((_, c) => Math.max(...rows.map((r) => r[c].length)));
  const table = rows.map((r) => r.map((cell, c) => cell.padEnd(widths[c])).join('   ').trimEnd()).join('\n');
  const lines = [
    {
      command: 'kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName',
      output: table,
    },
  ];
  if (options.expose === 'ingress') {
    lines.push({
      command: 'kubectl get ingress',
      output:
        'NAME                    CLASS     HOSTS   ADDRESS      PORTS   AGE\n' +
        'hello-kubernetes-demo   traefik   *       172.18.0.2   80      42s',
    });
  }
  return lines;
}

// Everything the landing page shows for each chip, worked out when the site is
// built, so the page doesn't load the builder, YAML or the schema.
export function landingChips(schema, version) {
  return scenarios(schema).map((chip) => ({
    id: chip.id,
    label: chip.label,
    url: chip.url,
    message: chip.options.message,
    namespace: chip.options.namespace,
    replicas: Number(chip.options.replicas),
    helm: chip.id === 'default' ? quickStart.helm : helmInstall(chip.options, schema, version, { brief: true }),
    terminal: terminal(chip.options),
  }));
}
