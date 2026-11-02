// The config builder: a form for the options people change, the output for
// Helm and Kustomize, and a live preview of the app's page. The output comes
// from src/lib/builder.mjs and the page from src/lib/preview.mjs, which the
// drift tests (tests/drift.mjs) check against the chart and the app.
import { useMemo, useState } from 'preact/hooks';
import type { JSX } from 'preact';
import * as builder from '../lib/builder.mjs';
import * as preview from '../lib/preview.mjs';
import schema from '../../../deploy/helm/hello-kubernetes/values.schema.json';
import chartYaml from '../../../deploy/helm/hello-kubernetes/Chart.yaml?raw';
import { previewPage } from '../lib/preview-assets';
import BrowserFrame from './BrowserFrame';
import '../styles/builder.css';

type Options = ReturnType<typeof builder.defaultOptions>;

const version = chartYaml.match(/^appVersion:\s*"?([^"\s]+)"?/m)![1];

// The schema's description of a value, for the help text under a field.
const p = schema.properties;
const help = {
  message: p.message.description,
  replicas: p.deployment.properties.replicaCount.description,
  serviceType: p.service.properties.type.description,
  servicePort: p.service.properties.port.description,
  pathPrefix: p.pathPrefix.description,
  rewritePath: p.rewritePath.description,
  ingressClass: p.ingress.properties.className.description,
  ingressHost: p.ingress.properties.host.description,
  gateway: p.httpRoute.properties.parentRefs.description,
  hostname: p.httpRoute.properties.hostnames.description,
  repository: p.deployment.properties.container.properties.image.properties.repository.description,
  tag: p.deployment.properties.container.properties.image.properties.tag.description,
};

function Field(props: { id: string; label: string; help?: string; children: JSX.Element }) {
  return (
    <div class="hk-field">
      <label for={props.id}>{props.label}</label>
      {props.children}
      {props.help && (
        <p class="hk-help" id={`${props.id}-help`}>
          {props.help}
        </p>
      )}
    </div>
  );
}

function CopyButton(props: { text: string; label: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      class="hk-copy"
      aria-label={done ? 'Copied' : `Copy ${props.label}`}
      title={done ? 'Copied' : 'Copy'}
      onClick={async () => {
        await navigator.clipboard.writeText(props.text);
        setDone(true);
        setTimeout(() => setDone(false), 2000);
      }}
    >
      <svg aria-hidden="true" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.75">
        {done ? (
          <path d="M5 12l5 5L20 7" />
        ) : (
          <>
            <rect x="9" y="9" width="11" height="11" rx="2" />
            <path d="M5 15V5a2 2 0 0 1 2-2h10" />
          </>
        )}
      </svg>
    </button>
  );
}

function Code(props: { title: string; text: string }) {
  return (
    <div class="hk-file">
      <div class="hk-file-header">
        <span>{props.title}</span>
        <CopyButton text={props.text} label={props.title} />
      </div>
      <pre tabIndex={0}>
        <code>{props.text}</code>
      </pre>
    </div>
  );
}

const tabs = [
  { id: 'helm', label: 'Helm' },
  { id: 'values', label: 'values.yaml' },
  { id: 'kustomize', label: 'Kustomize' },
  { id: 'template', label: 'helm template' },
] as const;

export default function ConfigBuilder() {
  const [o, setOptions] = useState<Options>(builder.defaultOptions(schema));
  const [tab, setTab] = useState<(typeof tabs)[number]['id']>('helm');
  const [request, setRequest] = useState(0);
  const [arch, setArch] = useState('linux/amd64');

  const set = (key: keyof Options) => (event: Event) => {
    const target = event.currentTarget as HTMLInputElement;
    const value = target.type === 'checkbox' ? target.checked : target.value;
    const next = { ...o, [key]: value };
    // Behind an Ingress or a Gateway, the app needs no public address.
    if (key === 'expose' && value !== 'none' && o.serviceType === 'LoadBalancer') next.serviceType = 'ClusterIP';
    setOptions(next);
  };

  // The preview: one of the pods answers each request.
  const replicas = Math.max(0, Number(o.replicas) || 0);
  const pod = replicas ? request % replicas : 0;
  const page = useMemo(() => {
    const image = `${builder.repositories[o.registry as keyof typeof builder.repositories]}:${o.tag || version}`;
    return previewPage({
      MESSAGE: o.message,
      KUBERNETES_NAMESPACE: o.namespace,
      KUBERNETES_POD_NAME: preview.podName(o.release, pod),
      KUBERNETES_NODE_NAME: preview.nodeName(pod),
      CONTAINER_IMAGE: image,
      nodeOS: 'Linux 6.8.0',
      arch,
    });
  }, [o.message, o.namespace, o.release, o.registry, o.tag, pod, arch]);

  // The address the page would be served at: the host from the options, or
  // hello.example.com, which is reserved for documentation; the Service's port
  // when the app is reached through the Service itself; and the path prefix.
  const host =
    (o.expose === 'ingress' && o.ingressHost) || (o.expose === 'gateway' && o.hostname) || 'hello.example.com';
  const port = o.expose === 'none' && Number(o.servicePort) !== 80 ? `:${Number(o.servicePort)}` : '';
  const url = `http://${host}${port}${preview.normalisePrefix(o.pathPrefix)}/`;

  const notes = builder.notes(o);
  const files = builder.kustomize(o, schema, version);

  return (
    <div class="hk-builder not-content">
      <div class="hk-builder-body">
        <form class="hk-form" onSubmit={(e) => e.preventDefault()}>
          <fieldset>
            <legend>Release</legend>
            <Field id="hk-release" label="Release name">
              <input id="hk-release" value={o.release} onInput={set('release')} pattern="[a-z0-9]([a-z0-9\-]*[a-z0-9])?" required />
            </Field>
            <Field id="hk-namespace" label="Namespace">
              <input id="hk-namespace" value={o.namespace} onInput={set('namespace')} required />
            </Field>
          </fieldset>

          <fieldset>
            <legend>App</legend>
            <Field id="hk-message" label="Message" help={help.message}>
              <input id="hk-message" value={o.message} placeholder="Hello world!" onInput={set('message')} aria-describedby="hk-message-help" />
            </Field>
            <Field id="hk-replicas" label="Replicas" help={help.replicas}>
              <input id="hk-replicas" type="number" min={0} max={20} value={o.replicas} onInput={set('replicas')} aria-describedby="hk-replicas-help" />
            </Field>
          </fieldset>

          <fieldset>
            <legend>Service</legend>
            <Field id="hk-service-type" label="Type" help={help.serviceType}>
              <select id="hk-service-type" value={o.serviceType} onChange={set('serviceType')} aria-describedby="hk-service-type-help">
                {p.service.properties.type.enum.map((t: string) => (
                  <option value={t}>{t}</option>
                ))}
              </select>
            </Field>
            <Field id="hk-service-port" label="Port" help={help.servicePort}>
              <input id="hk-service-port" type="number" min={1} max={65535} value={o.servicePort} onInput={set('servicePort')} aria-describedby="hk-service-port-help" />
            </Field>
          </fieldset>

          <fieldset>
            <legend>Expose</legend>
            <div class="hk-choice" role="radiogroup" aria-label="Expose the app">
              {[
                ['none', 'Service only'],
                ['ingress', 'Ingress'],
                ['gateway', 'Gateway'],
              ].map(([value, label]) => (
                <label>
                  <input type="radio" name="hk-expose" value={value} checked={o.expose === value} onChange={set('expose')} />
                  {label}
                </label>
              ))}
            </div>
            {o.expose === 'ingress' && (
              <>
                <Field id="hk-ingress-class" label="Ingress class" help={help.ingressClass}>
                  <input id="hk-ingress-class" value={o.ingressClass} placeholder="traefik" onInput={set('ingressClass')} aria-describedby="hk-ingress-class-help" />
                </Field>
                <Field id="hk-ingress-host" label="Host" help={help.ingressHost}>
                  <input id="hk-ingress-host" value={o.ingressHost} placeholder="hello.example.com" onInput={set('ingressHost')} aria-describedby="hk-ingress-host-help" />
                </Field>
              </>
            )}
            {o.expose === 'gateway' && (
              <>
                <Field id="hk-gateway-name" label="Gateway" help={help.gateway}>
                  <input id="hk-gateway-name" value={o.gatewayName} placeholder="my-gateway" onInput={set('gatewayName')} aria-describedby="hk-gateway-name-help" />
                </Field>
                <Field id="hk-gateway-namespace" label="Gateway namespace">
                  <input id="hk-gateway-namespace" value={o.gatewayNamespace} placeholder="gateway-system" onInput={set('gatewayNamespace')} />
                </Field>
                <Field id="hk-hostname" label="Host name" help={help.hostname}>
                  <input id="hk-hostname" value={o.hostname} placeholder="hello.example.com" onInput={set('hostname')} aria-describedby="hk-hostname-help" />
                </Field>
              </>
            )}
            <Field id="hk-prefix" label="Path prefix" help={help.pathPrefix}>
              <input id="hk-prefix" value={o.pathPrefix} placeholder="/app/hello" onInput={set('pathPrefix')} aria-describedby="hk-prefix-help" />
            </Field>
            {o.pathPrefix.trim() && (
              <div class="hk-field hk-check">
                <label>
                  <input type="checkbox" checked={o.rewritePath} onChange={set('rewritePath')} aria-describedby="hk-rewrite-help" />
                  The proxy strips the prefix (<code>rewritePath</code>)
                </label>
                <p class="hk-help" id="hk-rewrite-help">
                  {help.rewritePath}
                </p>
              </div>
            )}
          </fieldset>

          <fieldset>
            <legend>Image</legend>
            <Field id="hk-registry" label="Registry" help={help.repository}>
              <select id="hk-registry" value={o.registry} onChange={set('registry')} aria-describedby="hk-registry-help">
                <option value="dockerhub">Docker Hub</option>
                <option value="ghcr">GitHub Container Registry</option>
              </select>
            </Field>
            <Field id="hk-tag" label="Tag" help={help.tag}>
              <input id="hk-tag" value={o.tag} placeholder={version} onInput={set('tag')} aria-describedby="hk-tag-help" />
            </Field>
          </fieldset>
          <p class="hk-help">
            Every other value is in the <a href="/hello-kubernetes/docs/configure/values/">values reference</a>.
          </p>
        </form>

        <div class="hk-side">
          <div class="hk-preview">
            <div class="hk-preview-bar">
              <span>Preview</span>
              <select aria-label="Node architecture" value={arch} onChange={(e) => setArch((e.currentTarget as HTMLSelectElement).value)}>
                <option value="linux/amd64">amd64 node</option>
                <option value="linux/arm64">arm64 node</option>
              </select>
            </div>
            <BrowserFrame
              url={url}
              page={page}
              empty={replicas ? undefined : 'With 0 replicas, no pod answers.'}
              reloadDisabled={replicas < 2}
              onReload={() => setRequest(request + 1)}
            />
            <p class="hk-help">
              {replicas > 1
                ? `Reload the page: the Service sends each request to one of ${replicas} pods.`
                : 'With one pod, every request reaches the same pod.'}
            </p>
          </div>

          <div class="hk-output">
            <div class="hk-tabs" role="tablist" aria-label="Output">
              {tabs.map((t) => (
                <button
                  type="button"
                  role="tab"
                  id={`hk-tab-${t.id}`}
                  aria-selected={tab === t.id}
                  aria-controls="hk-panel"
                  tabIndex={tab === t.id ? 0 : -1}
                  onClick={() => setTab(t.id)}
                  onKeyDown={(e) => {
                    const step = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
                    if (!step) return;
                    const next = tabs[(tabs.findIndex((x) => x.id === tab) + step + tabs.length) % tabs.length];
                    setTab(next.id);
                    document.getElementById(`hk-tab-${next.id}`)?.focus();
                  }}
                >
                  {t.label}
                </button>
              ))}
            </div>
            <div class="hk-panel" id="hk-panel" role="tabpanel" aria-labelledby={`hk-tab-${tab}`}>
              {tab === 'helm' && <Code title="Terminal" text={builder.helmInstall(o, schema, version)} />}
              {tab === 'values' && (
                <>
                  <Code title="values.yaml" text={builder.valuesYaml(o, schema)} />
                  <Code title="Terminal" text={builder.helmInstallWithValues(o, version)} />
                </>
              )}
              {tab === 'kustomize' && (
                <>
                  <p class="hk-help">
                    The release file is the chart rendered with the release name <code>demo</code>, so the resources are
                    named <code>hello-kubernetes-demo</code>. Put these files in a folder, then run{' '}
                    <code>kubectl apply -k .</code>
                  </p>
                  {Object.entries(files).map(([name, text]) => (
                    <Code title={name} text={text} />
                  ))}
                </>
              )}
              {tab === 'template' && <Code title="Terminal" text={builder.helmTemplate(o, schema, version)} />}
            </div>
            {notes.length > 0 && (
              <ul class="hk-notes">
                {notes.map((n) => (
                  <li>{n}</li>
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
