// The landing page's interactive part: the Helm command under the headline,
// and the mock-up of a browser and a terminal, with "Try one:" chips that
// change all three together. The chips are in src/lib/scenarios.mjs. The
// preview's assets load only when the mock-up comes into view.
import { useEffect, useRef, useState } from 'preact/hooks';
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

  // The app's 800 by 600 page, scaled to the width of the browser frame.
  const frame = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.8);
  useEffect(() => {
    if (!frame.current) return;
    const observer = new ResizeObserver(([entry]) => setScale(Math.min(1, entry.contentRect.width / 800)));
    observer.observe(frame.current);
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
      <div class="hk-land-install">
        <CommandBox command={chip.helm} />
        <p class="hk-land-under">
          Paste it into a terminal with access to your cluster.{' '}
          <a href={`${base}docs/start-here/overview/#where-to-start`}>All the ways to deploy →</a>
        </p>
      </div>

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

      <div class="hk-land-mockup" ref={mockup}>
        <div class="hk-land-browser">
          <div class="hk-land-bar">
            <span class="hk-land-dots" aria-hidden="true">
              <i></i>
              <i></i>
              <i></i>
            </span>
            <span class="hk-land-url">{chip.url}</span>
            <button
              type="button"
              class="hk-land-reload"
              title="Send another request"
              aria-label="Send another request"
              onClick={() => setRequest(request + 1)}
            >
              <svg aria-hidden="true" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7" />
              </svg>
            </button>
          </div>
          <div class="hk-land-page" ref={frame} style={{ height: `${600 * scale}px` }}>
            {page ? (
              <iframe
                title="The hello-kubernetes page"
                sandbox=""
                srcdoc={page}
                scrolling="no"
                width={800}
                height={600}
                style={{ transform: `scale(${scale})` }}
              />
            ) : (
              <p>Loading the preview…</p>
            )}
          </div>
        </div>
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
