---
title: Run locally
description: Make the app find its files from its own folder, and add make run, which installs the dependencies from the lockfile when they are out of date.
type: plan
status: done
areas: [app, ci, operations]
issues: [85]
created: 2026-10-28
updated: 2026-10-28
---

# Run locally

## Intent

Running the app in the devcontainer was easy to get wrong. The app read `package.json`, `views/` and `static/` relative to the directory it was started from, so `node src/app/server.js` from the repo root failed. And `src/app/node_modules` is untracked, so it went stale when `package-lock.json` changed: after 2.2, an old install failed with `TypeError: engine is not a function`. The maintainer found both while reviewing #84.

This is a follow-up in workstream 2 of the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app).

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| Paths | `server.js` resolves `package.json`, `views` and `static` with `path.join(__dirname, …)`. The image is unchanged: its working directory is already the app folder. |
| `make run` | Depends on `src/app/node_modules/.package-lock.json`, which `npm ci` writes. Make runs `npm ci --ignore-scripts` when that file is missing or older than `src/app/package-lock.json`, and then starts `node src/app/server.js`. Environment variables pass through, for example `PORT=9090 make run`. |
| `npm ci`, not `npm install` | The old docs said `npm install`, which can rewrite the lockfile. `npm ci` installs exactly what it lists, the same as the image build. |

## Tracking

- **Issue:** [#85](https://github.com/paulbouwer/hello-kubernetes/issues/85), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), found while reviewing #84.
- **Branch:** `fix/85-run-from-anywhere`, from `release-1.11`.
- **Labels, milestone, assignee:** `bug`, `area:app`, `area:ci`, `area:operations`, `v1.11`, @paulbouwer.

## Validation

| Check | How |
|---|---|
| Any directory | `node …/src/app/server.js` started from the repo root, from `src/app` and from `/tmp`: the page, the stylesheet and the image return 200, and the page uses the layout. |
| `make run` | With `node_modules` missing, and with the lockfile newer: it runs `npm ci`, then serves the page. When up to date: it starts at once without installing. Each run logs its own "Listening" line, and no app is left running. |
| Image unchanged | Against the 2.4 image, for the defaults, `MESSAGE`, `PORT`, each prefix and `LOG_LEVEL=debug`: the same page byte for byte, and the same log fields and line counts. I1 to I3, I5a and the proxy tests pass. |
