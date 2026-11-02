<!-- The hand-written top of the 1.11.0 release notes. At the release, it goes
above GitHub's generated notes, which list every PR by label
(.github/release.yml). Check the Node.js security release before quoting
versions (deprecation.md, Caveats). -->

# hello-kubernetes 1.11.0

The first release in five years. hello-kubernetes is a small web app to deploy on a Kubernetes cluster: its page shows the namespace, pod and node that answered. This release brings it up to date and makes it safe to run, with the same page and the same settings.

**Docs:** https://paulbouwer.github.io/hello-kubernetes/

## Highlights

- **Up to date and secure by default.** Node.js 24 on Alpine, with no package manager in the image. It runs as the numeric user 1000, with a read-only root filesystem, no privileges, and the restricted Pod Security Standard met.
- **amd64 and arm64.** One image for both, with an SBOM and signed SLSA provenance.
- **A published Helm chart:** `oci://ghcr.io/paulbouwer/charts/hello-kubernetes`, also on Artifact Hub. It can create an Ingress or a Gateway API HTTPRoute, under any path prefix, and checks your values against a schema.
- **A release file:** `hello-kubernetes.yaml`, the chart rendered with its defaults, for `kubectl apply` or Kustomize.
- **A website** with the docs, a config builder with a live preview of the page, and `llms.txt` and Markdown copies for AI agents.
- **No requests to other sites.** The page's font is now part of the image.

## Where to get it

| | |
|---|---|
| Image (recommended) | `ghcr.io/paulbouwer/hello-kubernetes:1.11.0` |
| Image | `paulbouwer/hello-kubernetes:1.11.0` |
| Helm chart | `oci://ghcr.io/paulbouwer/charts/hello-kubernetes --version 1.11.0` |
| Release file | `hello-kubernetes.yaml`, attached below |

We recommend GHCR: it has no Docker Hub pull limits. Both registries get every 1.x release, with the same SBOM and signed provenance. In 2.0, GHCR becomes the chart's default. The tags `1`, `1.11` and `1.11.0` all point at this release.

## Upgrading from 1.10

Your 1.10 settings keep working. Upgrade a Helm release from the published chart with `--reset-then-reuse-values`:

```bash
helm upgrade <release> oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace <namespace> --version 1.11.0 --reset-then-reuse-values --wait
```

Don't use `--reuse-values`: it fails, because the 1.10 values have none of the new settings. The old `ingress.pathPrefix` and `ingress.rewritePath` values still work, and are deprecated; use `pathPrefix` and `rewritePath`. See [Upgrading from 1.10](https://paulbouwer.github.io/hello-kubernetes/docs/reference/upgrading/).

## The old image tags

The images before 1.11 are unsupported and have known security vulnerabilities, and 1.0 to 1.5 run as root. Right after this release, every old tag, from `1.0` to `1.10.1` and `1.10`, shows a clear warning at the top of its page, and a notice in its logs, pointing here. Nothing else about them changes. Each original stays available as `<tag>-original`, for example `1.5-original`, for 4 weeks. The details are in the pinned issue.

## Thanks

This release picks up fixes and ideas the community sent in while the project was quiet. Thank you, and sorry it took so long:

- @khetho and @ngaffa: Helm probes with an ingress path prefix (#30, #44)
- @Alestrix: `runAsNonRoot` support (#35)
- @MrRoundRobin and @chazapis: multi-arch images (#40, #46), with diagnosis and follow-ups from @vorburger, @MichaelMichaelMichaelMichaelMichael and @rthrprnt (#16)
- @NikolaiThingnesLeira: flagging the outdated base image (#45)
- @hotspoons: asset paths without a render prefix (#38)
- @kimllee and @frayos: the `networking.k8s.io/v1` ingress example (#31), with input from @dcorbe
- @simonw: clean-up instructions (#28)
- @STRRL: the single-file manifest (#29)
- @weironz: the official chart listing (#23)
