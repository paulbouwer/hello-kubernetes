---
title: App dependencies
description: Upgrade the app to Express 5, express-handlebars 9, pino 10 and pino-http 11 with a 7-day release cooldown, and stop the app cleanly on SIGTERM.
type: plan
status: active
areas: [app]
issues: [77]
created: 2026-10-28
updated: 2026-10-28
---

# App dependencies

## Intent

The app's dependencies were several majors behind, and `express-pino-logger` is deprecated. The app also ignored SIGTERM, so a container or pod waited for the full grace period before it was killed. This work upgrades the dependencies with no change for people who use the app, and makes it stop at once.

This is work item 2.2 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#2-image-and-app). The reasons are in [image.md](../../roadmap/1.x/image.md#dependency-upgrades) and row 2 of [review.md](../../roadmap/1.x/review.md#fixes-effort-and-impact).

## Decisions

Made on 2026-10-28.

| Decision | Result |
|---|---|
| Versions | Express 5.3.0 (not 4.22.3), express-handlebars 9.0.2, pino 10.4.0, and pino-http 11.0.0 in place of `express-pino-logger`. The direct `handlebars` dependency is removed: `server.js` doesn't use it, and express-handlebars brings its own. |
| Release cooldown | Every package version is at least 7 days old when it is chosen. A compromised release is usually found and pulled within hours or a few days. A week covers most cases, and two weeks adds little while it delays real fixes. The lockfile is built with `npm install --before=2026-10-21`. AGENTS.md rule 8 and `cooldown: default-days: 7` in `dependabot.yml` set the same rule. |
| Security fixes | A newer release is taken only to fix a vulnerability that the app can actually reach, and only after its provenance, publisher and diff are checked. A fix for a vulnerability that can't be reached waits for the cooldown. |
| body-parser 2.3.0 | Kept for now. It has a HIGH finding (GHSA-27r3-jxmh-p828), which a compressed request body triggers in an app that parses bodies. This app parses no bodies, so it can't be reached. 2.4.0, the fix, is 7 days old on 2026-10-29. |
| qs 6.16.1 | The 7-day cutoff includes it, so the MEDIUM finding (GHSA-6pq8-jhm2-2vcw) is fixed. That finding could not be reached either: the app never calls `qs.stringify`. |
| Shutdown | On SIGTERM or SIGINT, the app logs the signal, stops accepting connections, closes idle keep-alive connections, and exits when in-flight requests finish, or after 5 seconds. |
| Listen errors | Express 5 passes a listen error to the callback instead of throwing. The app logs it and exits with 1, as before. |

## Tracking

- **Issue:** [#77](https://github.com/paulbouwer/hello-kubernetes/issues/77), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54), blocked by #75.
- **Branch:** `chore/77-app-dependencies`, from `release-1.11`.
- **Labels, milestone, assignee:** `enhancement`, `area:app`, `v1.11`, @paulbouwer.

## Work

1. Update `package.json`, and build the lockfile in `node:24-alpine` with `--before`.
2. In `server.js`: `engine()` from express-handlebars, `pino-http`, the listen error, and the shutdown handler.
3. Add the cooldown to AGENTS.md and `dependabot.yml`.
4. Mark the 2.1 work package as done, which the 2.1 PR missed.

## Validation

| Check | How |
|---|---|
| Versions and age | The image has the versions above. Every version in the lockfile was published before the cutoff (checked against the npm registry). |
| No behaviour change | Against the 2.1 image, for the default settings, `MESSAGE`, `PORT`, both prefixes, and `LOG_LEVEL=debug`: the same page, 404 status and body, response headers, log fields (including inside `req` and `res`) and number of log lines. |
| Shutdown | `docker stop` time and exit code, with no connections, with an idle keep-alive connection, and with a request that never finishes (the 5-second cap). SIGINT too. |
| Listen error | A second app on the same port exits with 1 and logs the error. |
| Image tests and scan | I1 to I3 pass. Trivy: only the body-parser finding, which can't be reached. |

## Open

- **Bump body-parser to 2.4.0** on or after 2026-10-29, when it is 7 days old. If 3.1 makes the scan fail on fixable HIGH findings before then, ignore the finding with an expiry date.
