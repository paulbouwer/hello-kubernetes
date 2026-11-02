// The landing page's interactive part: "Try one:" chips, then the Helm command,
// so the chips stay in place as the command changes length, then
// and the mock-up of a browser and a terminal, with "Try one:" chips that
// change all three together. The chips are in src/lib/scenarios.mjs. The
// preview's assets load only when the mock-up comes into view.
import { useEffect, useRef, useState } from 'preact/hooks';
import BrowserFrame from './BrowserFrame';
import { nodeName, podName } from '../lib/pods.mjs';
import '../styles/landing.css';

const base = import.meta.env.BASE_URL;
type PreviewPage = typeof import('../lib/preview-assets').previewPage;

// A chip, as src/lib/scenarios.mjs (landingChips) works it out at build time.
export type Chip = {
  id: string;
  label: string;
  url: string;
  message: string;
  namespace: string;
  replicas: number;
  helm: string;
  terminal: { command: string; output: string }[];
};

function CopyButton(props: { text: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      class="hk-land-copy"
      onClick={async () => {
        await navigator.clipboard.writeText(props.text);
        setDone(true);
        setTimeout(() => setDone(false), 2000);
      }}
    >
      {done ? 'Copied' : 'Copy'}
    </button>
  );
}

// The command, with a $ prompt that shows but isn't copied.
function CommandBox(props: { command: string }) {
  return (
    <div class="hk-land-command">
      <pre tabIndex={0}>
        <code>{props.command}</code>
      </pre>
      <CopyButton text={props.command} />
    </div>
  );
}

export default function LandingDemo(props: { chips: Chip[]; version: string }) {
  const { chips, version } = props;
  const [chipId, setChipId] = useState('default');
  const [request, setRequest] = useState(0);
  const chip = chips.find((c) => c.id === chipId)!;

  // Load the preview's assets when the mock-up comes into view.
  const mockup = useRef<HTMLDivElement>(null);
  const [previewPage, setPreviewPage] = useState<PreviewPage | null>(null);
  useEffect(() => {
    if (!mockup.current) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        observer.disconnect();
        import('../lib/preview-assets').then((m) => setPreviewPage(() => m.previewPage));
      },
      { rootMargin: '200px' },
    );
    observer.observe(mockup.current);
    return () => observer.disconnect();
  }, []);

  const replicas = chip.replicas;
  const pod = request % replicas;
  const page = previewPage?.({
    MESSAGE: chip.message,
    KUBERNETES_NAMESPACE: chip.namespace,
    KUBERNETES_POD_NAME: podName('demo', pod),
    KUBERNETES_NODE_NAME: nodeName(pod),
    CONTAINER_IMAGE: `paulbouwer/hello-kubernetes:${version}`,
    nodeOS: 'Linux 6.8.0',
    arch: 'linux/amd64',
  });

  return (
    <div class="hk-land-demo">
      <div class="hk-land-try">
        <span>Try one:</span>
        {chips.map((c) => (
          <button
            type="button"
            class="hk-land-chip"
            aria-pressed={c.id === chipId}
            onClick={() => {
              setChipId(c.id);
              setRequest(0);
            }}
          >
            {c.label}
          </button>
        ))}
      </div>

      <div class="hk-land-install">
        <CommandBox command={chip.helm} />
        <p class="hk-land-under">
          Paste it into a terminal with access to your cluster.{' '}
          <a href={`${base}docs/start-here/overview/#where-to-start`}>All the ways to deploy →</a>
        </p>
      </div>

      <div class="hk-land-mockup" ref={mockup}>
        <BrowserFrame url={chip.url} page={page} onReload={() => setRequest(request + 1)} />
        <div class="hk-land-terminal" tabIndex={0} aria-label="Terminal output">
          {chip.terminal.map((l) => (
            <>
              <p class="hk-land-prompt">{l.command}</p>
              <pre>
                {/* The pod that answered the preview is highlighted. */}
                {l.output.split('\n').map((line) => (
                  <span class={line.startsWith(podName('demo', pod) + ' ') ? 'hk-land-answered' : undefined}>
                    {line + '\n'}
                  </span>
                ))}
              </pre>
            </>
          ))}
          <p class="hk-land-hint">
            {replicas > 1
              ? `Reload the page: the Service sends each request to one of ${replicas} pods.`
              : 'One pod answers every request.'}
          </p>
        </div>
      </div>
    </div>
  );
}
