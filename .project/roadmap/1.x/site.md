---
title: Website
description: GitHub Pages site with Astro and Starlight that holds the user docs, with a landing page, a live preview, a config builder and llms.txt.
type: plan
status: active
areas: [site]
created: 2026-10-22
updated: 2026-10-31
---

# Website

A product-style website for hello-kubernetes, hosted on GitHub Pages. It helps people understand what hello-kubernetes gives them, deploy it, and configure it, and it is easy for AI agents to read too.

The decisions below were agreed with the maintainer on 2026-10-31, question by question ([#135](https://github.com/paulbouwer/hello-kubernetes/issues/135)). They replace the plan of 2026-10-23, which built the site from copies of `docs/*.md`.

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **The site owns the user docs.** User docs are MDX pages in `site/`. `docs/` and `CONTRIBUTING.md` keep the contributor docs: the dev environment, building images, testing, local clusters and how the site is built. The README stays the GitHub front door. | Plain Markdown copied into the site can't hold synced tabs, rich code blocks or the live preview. |
| 2 | **Astro with Starlight**, on GitHub Pages. The microsandbox look is a theme we build. | Mintlify, which microsandbox uses, hosts the site itself, not on github.io. Starlight is what Herdr uses, supports MDX, synced tabs and themed code blocks, and is Node like the app. |
| 3 | **The site map** below, with guides, an upgrade page, and separate Ingress and Gateway pages. | Written for the people who use hello-kubernetes: demos, teaching and testing a cluster. |
| 4 | **The live site builds from `main`, and shows the latest release only.** Every PR builds the site in CI and keeps it as an artifact. The site goes live with 6.2. | Its pages describe the published chart, images and release file, which exist only after a release. |
| 5 | **Identity:** a text wordmark, `hello-kubernetes` in the code font; the app's charcoal and greys with Kubernetes blue (`#326CE5`) as the one accent; light, dark and Auto; Archivo, Inter and JetBrains Mono, self-hosted. | Related to the app without using the Kubernetes logo as the site's own, which the CNCF's trademark rules discourage. No third-party requests. |
| 6 | **Code blocks like microsandbox's.** | See [Code blocks](#code-blocks). |
| 7 | **Playwright, from its official container image pinned by digest,** for screenshots: of reference sites and our pages during the work, and of the app for the README at each release (`make screenshot`). | The image is verified by its digest (AGENTS.md rule 7), works the same locally and in CI, and keeps several hundred MB of browsers out of the devcontainer. |
| 8 | **The landing page** below: Herdr's layout, with an interactive mock-up and no stats row. | Herdr's page is the reference. A stats row adds API calls to every build and numbers that go stale. |
| 9 | **The config builder** gives the `helm install` command, `values.yaml` and Kustomize, not the rendered YAML, and CI checks it against the chart. | Rendering the manifests in the browser would mean a second copy of the chart's templates. |
| 10 | **The live preview** renders the app's real template in a sandboxed `iframe`. The builder uses **Preact**. The app's image bundles the Ubuntu font (5.1). | See [Live preview](#live-preview). |
| 11 | **Agents read Markdown generated from the built pages:** `llms.txt`, `llms-full.txt` and a `.md` copy of each page. | The MDX source contains components, which read poorly for an agent. |
| 12 | **The site is tested in CI** by a required `site` job, and E15 reads the MDX pages, with groups for alternative tabs. Accessibility problems block a merge only when serious or critical. | See [Testing](#testing). |
| 13 | **The defaults** below: Pagefind search, no analytics, English only, `paulbouwer.github.io/hello-kubernetes`. | Standard, and no third-party services. |
| 14 | **Six items**, 5.1–5.6, in the order in the [1.x work plan](../../work/2026-10-26-roadmap-1x/plan.md#5-website). | The landing page's mock-up needs the preview, so the preview comes first. |

A **Content Security Policy** in a `<meta>` tag was tried in 5.2 (#139), and **dropped**. Astro's generated policy blocked 26 of Starlight's inline scripts, which Astro doesn't hash, and 260 inline styles on code tokens. Making it work would have needed our own hashing step and `'unsafe-inline'` for style attributes. The Playwright checks still fail on any request to another site, in CI. The trial was to keep it only if Astro's generated hashes worked with Starlight without workarounds. It would stop a compromised dependency from loading code or sending data elsewhere, and enforce "no third-party requests". As a `<meta>` tag it can't stop framing (`frame-ancestors`) or send reports, because GitHub Pages can't send custom headers.

## References

Taken from screenshots of the live sites with Playwright on 2026-10-31. We match their style with our own CSS and components; their code and images aren't ours to reuse.

| Site | Built with | What we take from it |
|---|---|---|
| [microsandbox docs](https://docs.microsandbox.dev/sandboxes/overview) | Mintlify | **Code blocks:** one rounded frame with a thin border tinted in the accent colour, tabs in the frame's header with the active tab underlined in the accent, the copy button in the header's right corner, a near-black background in dark mode and a faint tint in light mode. A small icon next to each page in the sidebar. A hidden note for agents on every page. |
| [Herdr docs](https://herdr.dev/docs/install/) | Astro + Starlight | The install page's order: one section per method, then Verify, Update and Requirements. Dark, Light and Auto. Search in the header. |
| [Herdr landing page](https://herdr.dev/) | Hand-written HTML and CSS | A two-tone headline (white, then grey), pill tabs above the command box, a visual `$` prompt that isn't copied, a Copy button, a line under the command and a link to all the ways to install, and a large interactive mock-up with "Try one:" chips that change it. |

## Site map

```text
/                           Landing page
/docs/
  Start here
    Overview                What it is, what the page shows, what people use it for
    Quick start             kubectl | Helm tabs: deploy, reach, remove
  Deploy
    With Helm               install from the OCI chart, pin a version, upgrade, uninstall
    With kubectl            the release file, where LoadBalancer works, port-forward
    With Kustomize          the release file as a base, with patches
    Behind an Ingress       NGINX and Traefik, with and without rewriting
    Behind a Gateway        HTTPRoute, URLRewrite, Traefik and NGINX Gateway Fabric
  Configure
    Config builder          options to helm, values.yaml and Kustomize, with the live preview
    Values reference        every value, from values.schema.json
    Path prefixes           what pathPrefix and rewritePath do, with a diagram
    Security defaults       non-root, read-only filesystem, restricted Pod Security
  Guides
    Show load balancing     several pods across nodes, and the pod name changing
    Test your Ingress or Gateway   use hello-kubernetes to check a controller works
  Reference
    Container image         tags, platforms, checking signatures and SBOMs
    App settings            the environment variables, for running without the chart
    Upgrading from 1.10     renamed values, the numeric user, the new defaults
  For AI agents             llms.txt, the schema, using the docs from an agent
```

Contributing, the dev environment, CI and how the site is built stay in `docs/` and `CONTRIBUTING.md`. The footer links to them on GitHub.

Deploy pages follow Herdr's install page: the method, then **Verify** (a command and its expected result), **Upgrade**, **Uninstall** and **Requirements**.

The old `docs/deploy-using-helm.md`, `docs/deploy-with-ingress.md` and `docs/deploy-using-kubectl-and-kustomize.md` become short pages that point to the matching site pages, so existing links still lead somewhere.

## Look

### Identity

- **Wordmark:** `hello-kubernetes` in JetBrains Mono. The Kubernetes logo appears only where the app is shown: the live preview and the screenshot.
- **Colours:** the app's charcoal (`#333`) and greys, and Kubernetes blue (`#326CE5`) for links, buttons and the active tab.
- **Modes:** light, dark and Auto.
- **Fonts:** Archivo for headings, Inter for body text, JetBrains Mono for code, from `@fontsource` packages. Each is under the SIL Open Font Licence 1.1, and ships with its licence file.

### Code blocks

Built on Starlight's code blocks (Expressive Code), themed in our colours:

- **Code groups:** one frame, with Helm, kubectl and Kustomize tabs in its header, synced across pages and remembered.
- **The frame:** rounded corners, a thin blue border, and a dark blue-grey background (`#161d29`) in dark mode, or a pale blue (`#e7eefc`) in light mode, with a slightly different header bar.
- **Headers:** one height for every block. A code group's selected tab is light blue and underlined in blue. A block's only title, "Terminal" or a file name such as `values.yaml`, is light blue with no underline, because there is nothing to choose.
- **Copy:** a bare icon, with no box or background, always shown on the right of the header. In a code group it sits in the tab bar.
- **Commands:** titled "Terminal", with a terminal icon, and no `$` prompt in the copied text.
- **Output:** a block marked `output`: a dashed grey frame, quieter text, no header and no copy button.
- **Highlighted lines:** available, but used only when they help.

Settled with the maintainer on 2026-10-31, from screenshots (#139). The navy backgrounds tried first, from kubernetes.io's `#113e82`, were too strong.

There is no "Ask Assistant" button, which would need a hosted AI service.

## Page layout

The page column is up to 1000px wide (`--sl-content-width: 62.5rem`). Section headings are 24px (h2), 19px (h3) and 17px (h4) at every width; page titles keep Starlight's size. The previous and next links are small and quiet, and span the column. Buttons are rounded rectangles, never pills. Pages have no "Edit page" link. The footer links to report an issue, to contribute, and to the font licences (#139).

## Landing page

A custom Astro page (`site/src/pages/index.astro`), sharing fonts and colours with the docs. Top to bottom:

1. **Header:** the wordmark, *Docs*, *Config builder*, *GitHub*, and the theme switch.
2. **Hero:** "**Hello, Kubernetes.**" in white, then "**See which pod answered.**" in grey, and one sentence on what it is. Pill tabs, `kubectl | Helm`, above a command box with a `$` prompt and a Copy button. Under it: "Paste it into a terminal with access to your cluster." and "All the ways to deploy →".
3. **Mock-up:** a browser frame with the live preview, next to a terminal showing `kubectl get pods -o wide`. Chips such as *Default*, *Your message*, *Behind an Ingress* and *4 pods across nodes* change the preview, the terminal output and the hero's command together.
4. **Features:** "Shows which pod answered" · "Works behind an Ingress or a Gateway" · "Secure by default" · "Helm, kubectl or Kustomize" · "amd64 and arm64".
5. **Closing:** the command again, and links to the docs and the config builder.

Also an Open Graph image with the wordmark and the app, per-page titles and descriptions, and structured data (JSON-LD).

## Config builder

A hand-designed form for the options people change: the message, replicas, the service type and port, an Ingress or a Gateway (class, host, prefix, rewriting), and the image tag. Labels, descriptions, defaults and allowed values come from `values.schema.json`. "All values" links to the values reference.

It gives:

- the `helm install` command
- `values.yaml`
- a `kustomization.yaml` on the release file, with any extra files, such as an Ingress
- the `helm template` command, for the rendered YAML

**A CI test keeps it true to the chart.** It generates the builder's output for a set of option combinations, with the same code the page runs. `helm template` must accept the values and produce what was chosen. `kubectl kustomize` on the generated Kustomize, with the release file rendered locally, must match `helm template` for the same options.

## Live preview

- **The real template:** at build time, the site compiles `src/app/views/*.handlebars` and the app's `main.css`.
- **The context, built as `server.js` builds it:** the message, namespace, a realistic pod name, a node, and the image and its architecture. "Send another request" shows another pod's name when there are several replicas.
- **Isolated:** an `<iframe sandbox>` with no permissions, so no script runs and the frame has its own opaque origin. It is built with `srcdoc`, with the CSS, the Ubuntu font and the logo inlined, so it makes no requests. The message is escaped by Handlebars, and the sandbox stops scripts even if it weren't.
- **A CI test** renders the page through the preview's code and through the real app container, for the same settings, and compares the HTML.

**The app's font (5.1):** the app's page loaded Ubuntu from Google Fonts, which sends every visitor's browser to Google and fails in clusters with no internet access. The image bundles the font instead. Ubuntu is under the Ubuntu Font Licence 1.0, which allows bundling unmodified fonts if the copyright notice and the licence ship with them, so the image includes the licence file.

## Agent experience (AX)

| Where | What |
|---|---|
| Site | `/llms.txt`, in the [llmstxt.org](https://llmstxt.org/) format: the release, a note telling agents to open only the pages they need and to come back to this index, and a link to each page's Markdown. Generated from the built pages, for example by the `starlight-llms-txt` plugin, if it is maintained and its output for tabs is clean; otherwise by a tested script of our own. |
| Site | `/llms-full.txt`: all the docs in one file. |
| Site | A `.md` copy of every page, and a "Copy page as Markdown" button. |
| Site | `values.schema.json`, served next to `llms.txt` and listed in it as the configuration reference. |
| Site | A hidden note at the top of each page pointing agents to `/llms.txt`. |
| Site | The "For AI agents" page, which links to `AGENTS.md` for agents working on the repo. |
| Versions | The site is the latest release. `llms.txt` says that older versions' docs are in the repo at their tag. |

## Testing

- **E15** reads the MDX pages and the README. `` ```bash e2e `` marks a block, and `` ```bash e2e=kubectl `` puts it in a group: one flow from start to clean-up, such as one tab's deploy, check and remove. Each group runs on its own, and must leave nothing behind.
- **The `site` CI job**, a required check:
  - `astro check` and `astro build`
  - internal links and anchors (`starlight-links-validator`); external links aren't checked, to keep the build reliable
  - Playwright on every page, light and dark: fail on a console error, a CSP violation, or a request to another site
  - axe accessibility checks on every page: fail on serious and critical problems, report the rest. One exception: `label-content-name-mismatch` on Starlight's search button, which shows "Search Ctrl K" and is named "Search". The label is in the name, as WCAG 2.5.3 asks; axe counts the keyboard hint (#139).
- **The builder and preview drift tests** run where the app image is built.

## Defaults

| Topic | Default |
|---|---|
| Search | Starlight's built-in Pagefind, with no third-party service |
| Analytics | None |
| Feedback | A footer link to open an issue. No "Edit page" links, for a cleaner page (maintainer, 2026-10-31) |
| Also built | A sitemap, a 404 page, and a phone-width layout for every page |
| Languages | English only |
| Build | Node from the tool table, `npm ci` with a lockfile in `site/`, the 7-day cooldown, and Dependabot for `site/` |
| Domain | `paulbouwer.github.io/hello-kubernetes`, with Astro's `base` set to `/hello-kubernetes/` |
| Pages | The maintainer sets the repo's Pages source to GitHub Actions at 6.2 |
| README | A short pitch, the screenshot, the kubectl quick start, and links to the site and `CONTRIBUTING.md` |
| Writing | The repo's plain-English rules (AGENTS.md), on every page |
| Reviewing a PR | `npm run dev` in the devcontainer on port 4321, forwarded to the host, and screenshots in light, dark, desktop and phone width, kept as a CI artifact |

## Hosting and build

- **Workflow:** `.github/workflows/pages.yaml`, with `actions/upload-pages-artifact` and `actions/deploy-pages`, pinned to commit SHAs, with least-privilege `permissions:`. It builds on PRs and on pushes to `main`, and deploys only from `main`.
- **Layout:**

  ```text
  site/
    astro.config.mjs          # base path, Starlight, Preact, llms.txt, CSP
    package.json, package-lock.json
    src/pages/index.astro     # the landing page
    src/content/docs/         # the user docs, in MDX
    src/components/           # the config builder, the live preview, the landing mock-up
    src/styles/               # fonts, colours and the code block theme
    tests/                    # Playwright checks, and the builder and preview drift tests
  docs/                       # the contributor docs, and pointers for the old user docs
  ```
