# Website

The website in `site/` holds the user docs: what hello-kubernetes is, how to deploy it, and how to configure it. It is built with [Astro](https://astro.build/) and [Starlight](https://starlight.astro.build/), and published to GitHub Pages from `main`, at `paulbouwer.github.io/hello-kubernetes`. The decisions behind it are in [.project/roadmap/1.x/site.md](../.project/roadmap/1.x/site.md).

The docs in this folder, `docs/`, are for contributors. The site is for people who use hello-kubernetes.

## Work on the site

```bash
make site-dev
```

Open `http://localhost:4321/hello-kubernetes/`. The path matters: GitHub Pages serves the site under `/hello-kubernetes/`. The page reloads when you change a file. In the devcontainer, port 4321 is forwarded to your machine.

| Command | What it does |
|---|---|
| `make site` | Installs the packages from the lockfile, then runs `astro check` and `astro build` into `site/dist`. The build fails on a broken internal link or anchor. |
| `make site-test` | `make site`, then loads every page in Playwright, in light and dark mode. It fails on a console error, a request to another site, or a serious or critical accessibility problem (axe), and saves screenshots of every page, desktop and phone, in `site/test-results/screenshots/`. |
| `make screenshot` | Starts the k3d cluster (`make cluster-k3d`), installs the chart, and saves a screenshot of the app to `hello-kubernetes.png`, for the README. Run it for each release. |

Playwright runs from its official image, pinned by digest in the `Makefile`, so you don't install it. CI runs `make site-test` in the `site` job of `.github/workflows/pages.yaml`, a required check, and keeps the screenshots as an artifact on each PR.

## Write a page

Pages are MDX files in `site/src/content/docs/docs/`, one folder per sidebar section. The front matter gives the title, a description, the order in the sidebar, and an icon:

```yaml
---
title: Quick start
description: Deploy hello-kubernetes, reach it, and remove it, with kubectl or Helm.
sidebar:
  order: 2
  attrs:
    data-icon: rocket
---
```

`data-icon` is the name of one of [Starlight's icons](https://starlight.astro.build/reference/icons/).

Links to other pages use the full path, starting with `/hello-kubernetes/`, for example `/hello-kubernetes/docs/start-here/quick-start/`. The build rejects relative links.

Write in the repo's plain-English style (AGENTS.md): short sentences, active voice, one idea per sentence.

### Code blocks

| To show | Write |
|---|---|
| A command | a `bash` block. It gets a "Terminal" header and a copy button. Leave out the `$` prompt. |
| A file | a block with a title, such as ` ```yaml title="values.yaml" ` |
| The output of a command | a block marked `output`, such as ` ```text output `. It has a quieter, dashed frame, and no copy button. |
| The same step for Helm, kubectl or Kustomize | a code group: Starlight's `<Tabs syncKey="method">` inside our `<CodeGroup>`. The reader's choice of tab is kept on every page. |

A code group looks like this:

````mdx
import { Tabs, TabItem } from '@astrojs/starlight/components';
import CodeGroup from '../../../../components/CodeGroup.astro';

<CodeGroup>
<Tabs syncKey="method">
<TabItem label="kubectl">

```bash
kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
```

</TabItem>
<TabItem label="Helm">

```bash
helm install demo oci://ghcr.io/paulbouwer/charts/hello-kubernetes --wait
```

</TabItem>
</Tabs>
</CodeGroup>
````

## Dependencies

The site's packages are pinned in `site/package.json` and `site/package-lock.json`. Add or update a package with npm's `--before` option, so that every package, including its dependencies, was released at least 7 days ago (AGENTS.md rule 8):

```bash
cd site
npm install --save-exact --before=2026-10-25T00:00:00Z <package>@<version>
```

Dependabot proposes updates for `site/` weekly, with the same 7-day wait.

The fonts are self-hosted from `@fontsource` packages. `site/scripts/copy-font-licences.mjs` copies each font's licence into the built site, and the footer links to them.
