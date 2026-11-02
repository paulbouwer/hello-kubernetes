// A browser window around the live preview, for the landing page and the
// config builder: the address the page would be served at, a reload button
// that sends another request, and the app's page in a sandboxed iframe.
//
// The app's page is laid out for a desktop. It fills a wide frame at full
// size, and is scaled down to fit a narrow one. The frame is tall enough for
// the whole page, so it never scrolls.
import { useEffect, useRef, useState } from 'preact/hooks';
import '../styles/browser.css';

const pageWidth = 800;
const pageHeight = 600;

export default function BrowserFrame(props: {
  url: string;
  // The page's HTML, or undefined while it loads.
  page?: string;
  // Shown in place of the page, for example when no pod answers.
  empty?: string;
  onReload: () => void;
  reloadDisabled?: boolean;
}) {
  const frame = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(pageWidth);
  const scale = Math.min(1, width / pageWidth);
  useEffect(() => {
    if (!frame.current) return;
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width));
    observer.observe(frame.current);
    return () => observer.disconnect();
  }, []);

  return (
    <div class="hk-browser">
      <div class="hk-browser-bar">
        <span class="hk-browser-dots" aria-hidden="true">
          <i></i>
          <i></i>
          <i></i>
        </span>
        <span class="hk-browser-url">{props.url}</span>
        <button
          type="button"
          class="hk-browser-reload"
          title="Send another request"
          aria-label="Send another request"
          disabled={props.reloadDisabled}
          onClick={props.onReload}
        >
          <svg aria-hidden="true" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7" />
          </svg>
        </button>
      </div>
      <div class="hk-browser-page" ref={frame} style={{ height: `${pageHeight * scale}px` }}>
        {props.empty ? (
          <p>{props.empty}</p>
        ) : props.page ? (
          <iframe
            title="Preview of the hello-kubernetes page"
            sandbox=""
            srcdoc={props.page}
            width={Math.max(width, pageWidth)}
            height={pageHeight}
            scrolling="no"
            style={{ transform: `scale(${scale})` }}
          />
        ) : (
          <p>Loading the preview…</p>
        )}
      </div>
    </div>
  );
}
