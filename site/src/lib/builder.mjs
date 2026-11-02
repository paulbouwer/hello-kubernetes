// The config builder's output: the options people change, turned into a
// helm install command, a values.yaml, a Kustomize setup on the release file,
// and a helm template command. The drift test (site/tests/drift.mjs) checks
// this output against the chart, so the page can't drift from it.
//
// Plain JavaScript, so the test runs it in Node as it is.
import { stringify } from 'yaml';

export const chartRef = 'oci://ghcr.io/paulbouwer/charts/hello-kubernetes';
export const repositories = {
  dockerhub: 'paulbouwer/hello-kubernetes',
  ghcr: 'ghcr.io/paulbouwer/hello-kubernetes',
};

// The options, and their starting values. The chart's defaults come from its
// schema (see defaultOptions); these are the builder's own.
export function defaultOptions(schema) {
  const p = schema.properties;
  return {
    release: 'hello',
    namespace: 'hello-kubernetes',
    message: '',
    replicas: p.deployment.properties.replicaCount.default,
    serviceType: p.service.properties.type.default,
    servicePort: p.service.properties.port.default,
    expose: 'none', // none, ingress or gateway
    pathPrefix: '',
    rewritePath: false, // the recommended setting; the chart's default is true
    ingressClass: '',
    ingressHost: '',
    gatewayName: '',
    gatewayNamespace: '',
    hostname: '',
    registry: 'dockerhub',
    tag: '',
  };
}

// The chart values that differ from the chart's defaults, as a nested object.
export function chartValues(o, schema) {
  const p = schema.properties;
  const values = {};
  if (o.message) values.message = o.message;
  const prefix = o.pathPrefix.trim();
  if (prefix) {
    values.pathPrefix = prefix;
    values.rewritePath = o.rewritePath;
  }
  if (o.expose === 'ingress') {
    values.ingress = { enabled: true };
    if (o.ingressClass) values.ingress.className = o.ingressClass;
    if (o.ingressHost) values.ingress.host = o.ingressHost;
  }
  if (o.expose === 'gateway') {
    const ref = { name: o.gatewayName || 'my-gateway' };
    if (o.gatewayNamespace) ref.namespace = o.gatewayNamespace;
    values.httpRoute = { enabled: true, parentRefs: [ref] };
    if (o.hostname) values.httpRoute.hostnames = [o.hostname];
  }
  const service = {};
  if (o.serviceType !== p.service.properties.type.default) service.type = o.serviceType;
  if (Number(o.servicePort) !== p.service.properties.port.default) service.port = Number(o.servicePort);
  if (Object.keys(service).length) values.service = service;
  const deployment = {};
  if (Number(o.replicas) !== p.deployment.properties.replicaCount.default) deployment.replicaCount = Number(o.replicas);
  const image = {};
  if (repositories[o.registry] !== repositories.dockerhub) image.repository = repositories[o.registry];
  if (o.tag) image.tag = String(o.tag);
  if (Object.keys(image).length) deployment.container = { image };
  if (Object.keys(deployment).length) values.deployment = deployment;
  return values;
}

// A value for the shell: bare when it is safe, otherwise in single quotes.
function shell(value) {
  return /^[A-Za-z0-9_./:@=,+-]+$/.test(value) ? value : `'${value.replaceAll("'", `'\\''`)}'`;
}

// --set flags for the values. Text that could read as a number or a boolean
// uses --set-string, so Helm keeps it as text.
export function setFlags(values, path = '') {
  const flags = [];
  for (const [key, value] of Object.entries(values)) {
    const name = path ? `${path}.${key}` : key;
    if (Array.isArray(value)) {
      value.forEach((item, i) => {
        if (typeof item === 'object') flags.push(...setFlags(item, `${name}[${i}]`));
        else flags.push(`--set-string ${shell(`${name}[${i}]=${item}`)}`);
      });
    } else if (typeof value === 'object') {
      flags.push(...setFlags(value, name));
    } else if (typeof value === 'string') {
      flags.push(`--set-string ${shell(`${name}=${value}`)}`);
    } else {
      flags.push(`--set ${shell(`${name}=${value}`)}`);
    }
  }
  return flags;
}

// brief, for the landing page: no --version, and no --namespace for the
// default namespace, as in the quick start.
function command(verb, o, version, extra, brief = false) {
  const lines = [`helm ${verb} ${o.release} ${chartRef}`];
  const scope = [];
  if (!brief) scope.push(`--version ${version}`);
  if (!brief || o.namespace !== 'default') {
    scope.push(`--namespace ${o.namespace}`);
    if (verb === 'install') scope.push('--create-namespace');
  }
  if (scope.length) lines.push(scope.join(' '));
  lines.push(...extra);
  if (verb === 'install') lines.push('--wait');
  return lines.join(' \\\n  ');
}

export function helmInstall(o, schema, version, { brief = false } = {}) {
  return command('install', o, version, setFlags(chartValues(o, schema)), brief);
}

export function valuesYaml(o, schema) {
  const values = chartValues(o, schema);
  return Object.keys(values).length ? stringify(values) : '# The chart defaults are all you need.\n';
}

export function helmInstallWithValues(o, version) {
  return command('install', o, version, ['--values values.yaml']);
}

export function helmTemplate(o, schema, version) {
  return command('template', o, version, setFlags(chartValues(o, schema)));
}

// The Kustomize setup: the release file as the base, with patches. The
// release file is the chart rendered with the release name demo, so the
// resources are named hello-kubernetes-demo. Returns { file name: content }.
export function kustomize(o, schema, version) {
  const p = schema.properties;
  const name = 'hello-kubernetes-demo';
  const labels = {
    'app.kubernetes.io/name': 'hello-kubernetes',
    'app.kubernetes.io/instance': 'demo',
    'app.kubernetes.io/version': version,
  };
  const prefix = (() => {
    const path = o.pathPrefix.trim().replace(/^\/+/, '').replace(/\/+$/, '');
    return path ? `/${path}` : '';
  })();
  const port = Number(o.servicePort);
  const files = {};
  const resources = [];
  if (o.namespace !== 'default') {
    files['namespace.yaml'] = stringify({ apiVersion: 'v1', kind: 'Namespace', metadata: { name: o.namespace } });
    resources.push('namespace.yaml');
  }
  resources.push(`https://github.com/paulbouwer/hello-kubernetes/releases/download/v${version}/hello-kubernetes.yaml`);

  if (o.expose === 'ingress') {
    const rule = {
      http: {
        paths: [
          { path: prefix || '/', pathType: 'Prefix', backend: { service: { name, port: { name: 'http' } } } },
        ],
      },
    };
    if (o.ingressHost) rule.host = o.ingressHost;
    const spec = {};
    if (o.ingressClass) spec.ingressClassName = o.ingressClass;
    spec.rules = [rule];
    files['ingress.yaml'] = stringify({
      apiVersion: 'networking.k8s.io/v1',
      kind: 'Ingress',
      metadata: { name, labels },
      spec,
    });
    resources.push('ingress.yaml');
  }
  if (o.expose === 'gateway') {
    const ref = { name: o.gatewayName || 'my-gateway' };
    if (o.gatewayNamespace) ref.namespace = o.gatewayNamespace;
    const rule = { matches: [{ path: { type: 'PathPrefix', value: prefix || '/' } }] };
    if (prefix && o.rewritePath) {
      rule.filters = [
        { type: 'URLRewrite', urlRewrite: { path: { type: 'ReplacePrefixMatch', replacePrefixMatch: '/' } } },
      ];
    }
    rule.backendRefs = [{ name, port }];
    const spec = { parentRefs: [ref] };
    if (o.hostname) spec.hostnames = [o.hostname];
    spec.rules = [rule];
    files['httproute.yaml'] = stringify({
      apiVersion: 'gateway.networking.k8s.io/v1',
      kind: 'HTTPRoute',
      metadata: { name, labels },
      spec,
    });
    resources.push('httproute.yaml');
  }

  const patches = [];
  const serviceOps = [];
  if (o.serviceType !== p.service.properties.type.default) {
    serviceOps.push({ op: 'replace', path: '/spec/type', value: o.serviceType });
  }
  if (port !== p.service.properties.port.default) {
    serviceOps.push({ op: 'replace', path: '/spec/ports/0/port', value: port });
  }
  if (serviceOps.length) patches.push({ target: { kind: 'Service', name }, patch: stringify(serviceOps).trimEnd() });

  // The Deployment, as a strategic merge patch: env vars merge by name.
  const container = { name: 'hello-kubernetes' };
  const env = [];
  const probes = {};
  if (o.message) env.push({ name: 'MESSAGE', value: o.message });
  if (prefix) {
    env.push({ name: 'HANDLER_PATH_PREFIX', value: o.rewritePath ? '' : prefix });
    env.push({ name: 'RENDER_PATH_PREFIX', value: prefix });
    if (!o.rewritePath) {
      probes.livenessProbe = { httpGet: { path: `${prefix}/` } };
      probes.readinessProbe = { httpGet: { path: `${prefix}/` } };
    }
  }
  if (o.registry !== 'dockerhub' || o.tag) {
    const image = `${repositories[o.registry]}:${o.tag || version}`;
    container.image = image;
    env.push({ name: 'CONTAINER_IMAGE', value: image });
  }
  if (env.length) container.env = env;
  Object.assign(container, probes);
  const deployment = {};
  if (Number(o.replicas) !== p.deployment.properties.replicaCount.default) deployment.replicas = Number(o.replicas);
  if (Object.keys(container).length > 1) deployment.template = { spec: { containers: [container] } };
  if (Object.keys(deployment).length) {
    patches.push({
      patch: stringify({ apiVersion: 'apps/v1', kind: 'Deployment', metadata: { name }, spec: deployment }).trimEnd(),
    });
  }

  const kustomization = { apiVersion: 'kustomize.config.k8s.io/v1beta1', kind: 'Kustomization' };
  if (o.namespace !== 'default') kustomization.namespace = o.namespace;
  kustomization.resources = resources;
  if (patches.length) kustomization.patches = patches;
  return { 'kustomization.yaml': stringify(kustomization), ...files };
}

// Notes to show next to the output.
export function notes(o) {
  const list = [];
  if (o.expose !== 'none' && o.serviceType === 'LoadBalancer') {
    list.push('Behind an Ingress or a Gateway, set the Service type to ClusterIP, so the app has no second, public address.');
  }
  if (o.expose === 'ingress' && o.pathPrefix.trim() && o.rewritePath) {
    list.push("With rewriting, an Ingress needs your controller's rewrite annotation. Without rewriting, it needs none.");
  }
  if (o.expose === 'gateway' && !o.gatewayName) {
    list.push('Name your Gateway. The output uses my-gateway until you do.');
  }
  return list;
}
