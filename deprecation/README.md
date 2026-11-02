# Deprecation images

The images that replace the old tags, `1.0` to `1.10.1` and `1.10`, with the original plus a warning on the page and a notice on startup. The plan, the decisions and the order are in [.project/roadmap/1.x/deprecation.md](../.project/roadmap/1.x/deprecation.md).

| File | What it is |
|---|---|
| `tags.txt` | Each old tag, the digest of its original image, and the user it runs as. |
| `banner.html` | The warning, added straight after `<body>`. `{{tag}}` becomes the tag. |
| `notice.js.in` | The startup notice. `{{tag}}` becomes the tag. |
| `patch.js` | Runs inside each original image at build time, with its own Node, to add the banner and the notice. |
| `deprecate.sh` | Builds, tests and publishes the images. |
| `check.mjs` | The checks: config (D1), page (D2), static files (D3), logs and start time (D4), and probes on kind (K1). |

```bash
deprecation/deprecate.sh build          # every tag, or name some: build 1.5 1.10.1
deprecation/deprecate.sh test           # needs docker, kind, kubectl and curl
```

`deprecation/deprecate.sh publish --yes` changes public tags on Docker Hub. It is for 7.1 only, after 1.11.0 ships, and it refuses to run before then.
