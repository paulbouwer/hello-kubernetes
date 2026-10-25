---
title: Website
description: GitHub Pages site with Astro and Starlight, landing page, docs style, config builder, llms.txt and agent experience.
type: plan
status: active
areas: [site]
created: 2026-10-22
updated: 2026-10-23
---

# Website

A product-style website for hello-kubernetes and its configuration, hosted on GitHub Pages, with a focus on agent experience (AX): making the repo and site easy for AI agents as well as people to read and use. This builds on [deploy.md](deploy.md) (rendered YAML, Kustomize patches, the chart values table) and E15 in [testing.md](testing.md) (running the docs' commands in CI).

## Summary

- **Astro with the Starlight docs theme**, built by a GitHub Actions workflow and published to `paulbouwer.github.io/hello-kubernetes`.
- **Landing page modelled on [herdr.dev](https://herdr.dev/)**, as a custom Astro page in the same project, sharing fonts and colours with the docs.
- **Docs style modelled on [Herdr's docs](https://herdr.dev/docs/install/) and [microsandbox](https://docs.microsandbox.dev/sandboxes/overview)**: terminal-style command frames, synced Helm | kubectl | Kustomize tabs, and a consistent page structure.
- **One copy of the docs.** A `prepare-docs` step copies `docs/*.md` into the site before each build.
- **Stand-out features:** a config builder and a live preview of the app's page, both running in the browser.
- **AX:** `llms.txt` linking to raw markdown at the release tag, `llms-full.txt`, a hidden note for agents on each page, `AGENTS.md` in the repo, and a `values.schema.json` for the chart.

## References

Checked in October 2026.

| Site | Built with | What to take from it |
|---|---|---|
| [herdr.dev](https://herdr.dev/) | Hand-written HTML and CSS | The landing page: short headline, copyable install command, stats row, a large clickable product mock-up built in HTML, short feature blocks, closing install command. Light and dark modes; Archivo, Inter and JetBrains Mono fonts. |
| [herdr.dev/docs](https://herdr.dev/docs/install/) | Astro + Starlight, custom styling | Commands in terminal-style frames. The install page goes: one section per method, then Verify, Update, Requirements. `llms.txt` links to raw markdown on GitHub at the release tag. Docs are copied into the site by a `prepare-docs.mjs` script. |
| [docs.microsandbox.dev](https://docs.microsandbox.dev/sandboxes/overview) | Mintlify (hosted service) | Code tabs per language, copy and "Ask Assistant" buttons on each code block, a hidden note on every page pointing agents to `/llms.txt`, every page available as `.md`. |

Both Herdr and microsandbox serve `llms.txt` and `llms-full.txt`.

### Other Starlight sites

Each reports Starlight as its generator.

| Site | Why it's worth a look | `llms.txt` |
|---|---|---|
| [starlight.astro.build](https://starlight.astro.build/) | Starlight's own site and default layout | — |
| [biomejs.dev](https://biomejs.dev/) | Polished product landing page on top of the docs | — |
| [v2.tauri.app](https://v2.tauri.app/) | Strong landing page, lots of guides and reference pages | ✓ |
| [openai.github.io/openai-agents-js](https://openai.github.io/openai-agents-js/) | Hosted on github.io under a project path, the same setup as here | ✓ |
| [knip.dev](https://knip.dev/) | A small open-source tool with a clean, simple site; closest in scale | — |
| [docs.astro.build](https://docs.astro.build/) | Starlight at large scale, with translations and search | — |

More on the [showcase page](https://starlight.astro.build/resources/showcase/).

## Choosing a site generator

| Option | Product feel | Upkeep | AX / llms.txt | Notes |
|---|---|---|---|---|
| **Astro + Starlight** | High; custom landing page plus docs | npm dependencies to keep current | Plugin generates `llms.txt`, `llms-full.txt` | What Herdr uses; interactive pieces are easy; Node, like the app |
| **Mintlify** | Highest out of the box | Low; it's a hosted service | Built in, including per-page `.md` | Hosts the site itself, so not on github.io, and ties the docs to one vendor |
| **VitePress** | High (hero landing page built in) | npm, but fewer packages | Community plugin | Vue-based, very fast, a little less flexible |
| **Hugo** (e.g. Hextra theme) | Good with a theme | Lowest: one binary, no packages | Custom output templates | Go templates, like Helm |
| **Docusaurus** | High | Heaviest (React) | Plugin | More than this project needs |
| **MkDocs Material** | Good, docs-first | Python | Plugin | Reportedly in maintenance mode since late 2025 (successor: Zensical); check first |
| **Jekyll** (GitHub's built-in) | Dated | No build workflow needed | Manual | Ruby, few plugins |
| **Plain HTML/CSS/JS** | Whatever you build | No dependencies | Hand-written | Docs end up duplicated rather than built from `docs/*.md` |

**Recommended: Astro + Starlight.** It's what Herdr uses, it can match microsandbox's main docs features (tabs, code frames, copy buttons), and it builds to static files for GitHub Pages.

**Not recommended: Mintlify**, despite the polish. It hosts the site itself rather than on github.io, and the docs would depend on one vendor.

**Low-maintenance alternative: Hugo**, if keeping dependencies to a minimum matters more. The trade-off is more hand-built theming and generating `llms.txt` with custom templates.

## Landing page

A custom Astro page (`site/src/pages/index.astro`) rather than Starlight's built-in splash layout, so it can look like Herdr's while sharing fonts, colours and the build with the docs. Top to bottom:

1. **Headline and command.** A short two-line headline, a one-sentence description, and the install command with a copy button, switchable between `kubectl apply` and `helm install`. A line underneath with platforms (amd64 · arm64) and the licence.
2. **Stats row.** Docker Hub pulls, GitHub stars and supported platforms, updated at build time.
3. **Product mock-up.** The live app preview (below) inside a browser frame, next to a terminal pane showing `kubectl get pods`. Changing options in the config builder updates both, the way Herdr's mock-up responds to clicks. Built in HTML, not a screenshot, so it stays sharp and accurate.
4. **Feature blocks.** Short headings with a line or two each, e.g. "Shows which pod answered", "Works behind an ingress", "Runs as non-root", "Helm, kubectl or Kustomize".
5. **Closing call to action.** The install command again, with links to the docs and the config builder.

Also: light and dark modes, an Open Graph image and description for link previews, and structured data (JSON-LD), as Herdr has.

## Docs

### Style

- **Theme Starlight to match the landing page**: fonts, colours and the light/dark toggle.
- **Terminal-style frames** for commands, with copy buttons (Starlight's built-in Expressive Code does this).
- **Synced tabs**: Helm | kubectl | Kustomize. Choosing a tab on one page selects it on every page, the way microsandbox switches languages (Starlight `<Tabs syncKey="method">`).
- **Callouts** for warnings, e.g. the probe path when `rewritePath: false`.

### Page structure

Deploy pages follow Herdr's install page:

1. **Deploy**: one section per method (Helm, kubectl, Kustomize), or synced tabs.
2. **Verify**: a command and its expected result, e.g. `curl -s localhost:8080 | grep "Hello world!"`.
3. **Upgrade.**
4. **Uninstall**: `helm uninstall` or `kubectl delete`, and deleting the namespace.
5. **Requirements**: Kubernetes version, Helm 3.x or 4.x, platforms.

### Pages

- **Get started:** the README quick start, including clean-up (from `community.md`).
- **Deploy:** with Helm, with plain YAML, with Kustomize, and with an ingress, from `docs/` and `deploy.md`.
- **Configuration reference:** every chart value, generated from `values.schema.json`.
- **Container image:** tags, architectures, digests, and debugging with `kubectl debug`, from `image.md`.
- **Using with AI agents:** links to `llms.txt`, `AGENTS.md` and the schema.

### One copy of the docs

A `site/scripts/prepare-docs.mjs` step copies `docs/*.md` into Starlight's content folder before each build, adding the frontmatter Starlight needs, as Herdr does. The docs stay readable on GitHub, and the site never has its own copies. The copied files are build output, so add them to `.gitignore`.

## Config builder

Pick a message, ingress or LoadBalancer, a path prefix and replicas, and the page outputs:

- the `helm install` command
- a `values.yaml`
- the Kustomize patch from `deploy.md`
- plain YAML.

It runs entirely in the browser, built from `values.schema.json` so the form and the chart can't drift apart. It drives the landing page mock-up as well as its own docs page.

## Live preview of the app

The app's page is a handlebars template (`src/app/views`), and handlebars runs in the browser. The site can render the real view with the chosen message and sample pod and node details, so people see the result before deploying. Using the real template means the preview stays accurate when the page changes.

## Agent experience (AX)

| Where | What |
|---|---|
| Site | `llms.txt` at the site root, in the [llmstxt.org](https://llmstxt.org/) format. Following Herdr: a title, the current release, a short note telling agents to open only the pages they need and to come back to this index rather than following links in the HTML pages, then links to the **raw markdown on GitHub at the release tag** (e.g. `https://raw.githubusercontent.com/paulbouwer/hello-kubernetes/v1.11.0/docs/deploy-using-helm.md`). Agents get the docs for that exact version, with no per-page markdown to generate. |
| Site | `llms.txt` also lists `values.schema.json` as the configuration reference, as Herdr lists its config JSON. |
| Site | `llms-full.txt`: all docs in one markdown file. |
| Site | A hidden note at the top of each page pointing agents to `/llms.txt`, as microsandbox does (a Starlight component override). |
| Repo | `AGENTS.md` at the root: how to build, test and render the chart, the repo layout, and conventions such as pinning actions to SHAs. It's the cross-tool convention, and agents read it automatically. |
| Chart | `values.schema.json`. Helm validates values against it, agents and editors get descriptions and allowed values, and it generates the config builder, the configuration reference page and the values table in `deploy.md`. One schema replaces three hand-maintained copies. |
| Docs | Commands that need no prompts, each followed by an expected result, so a person or agent can confirm each step worked. E15 in `testing.md` runs these in CI, which keeps them correct. |
| Release | Stable URLs (`releases/latest/download/hello-kubernetes.yaml`, image digests in the release notes) that agents can reference reliably. |

The release workflow should regenerate `llms.txt` with the new tag, so its links always point at the latest release's docs.

## Hosting and build

- **Workflow:** `.github/workflows/pages.yaml` using `actions/upload-pages-artifact` and `actions/deploy-pages`, pinned to commit SHAs like the other workflows, with least-privilege `permissions:` (`pages: write`, `id-token: write`).
- **Base path:** project sites are served under `/hello-kubernetes/`, so set Astro's `base`. A custom domain can come later.
- **Layout:**

  ```text
  site/                       # Astro + Starlight project
    astro.config.mjs          # base path, Starlight and llms.txt config
    scripts/prepare-docs.mjs  # copies ../docs/*.md into src/content/docs/
    src/pages/index.astro     # custom landing page
    src/content/docs/         # generated by prepare-docs (gitignored), plus site-only pages
    src/components/           # config builder, app preview, landing mock-up
    src/styles/               # shared fonts and colours for landing page and docs
  docs/                       # existing docs, still readable on GitHub
  deploy/helm/hello-kubernetes/values.schema.json
  AGENTS.md
  ```

- **Dependencies:** add `site/` to `dependabot.yml` (npm) alongside the app.

## Suggested order

1. `AGENTS.md` and `values.schema.json`. Useful immediately, with or without a site.
2. Scaffold Starlight in `site/` with `prepare-docs`, the existing docs and the Pages workflow.
3. Docs styling: theme, terminal frames, synced tabs, Verify/Upgrade/Uninstall/Requirements structure.
4. `llms.txt` with tagged raw links, `llms-full.txt`, and the hidden agent note.
5. Landing page.
6. Config builder, live preview and the landing page mock-up.
