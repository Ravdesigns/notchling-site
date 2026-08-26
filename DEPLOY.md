# Deploying the Notchling site on ZopDay

This is a static site packaged as a container. ZopDay builds the `Dockerfile` in
this repo and runs it — on a Kubernetes cluster or, now, on a plain Linux VM.

**The image is already built and tested locally** (nginx:1.27-alpine, ~static):
health check, all assets, the zip download and the custom 404 were verified
before this repo existed, so nothing here is theoretical.

## What the platform owner must connect first (one-time, org level)

ZopDay is a control plane over your own infrastructure. Before any deploy runs the
workspace needs **one** of:

- a connected cloud account + a registered Kubernetes cluster, **or**
- a plain Linux VM target (ZopDay installs Docker and Caddy onto it itself).

The VM route is the cheaper one for a single static site.

## Steps in the ZopDay console

1. Sign in at <https://zop.dev/signin> → **zopday**.
2. **Projects → New project** — name it `notchling`.
3. **New environment** — pick the cluster/space or the VM target, and a namespace.
4. **Add deployment** — repository `https://github.com/Ravdesigns/notchling-site`,
   branch `main`.
5. ZopDay detects the `Dockerfile` and builds. If it asks for service settings:
   - **Container port:** `8080` (the image also honours an injected `$PORT`)
   - **Health check path:** `/healthz` → returns `200 ok`
6. **Deploy**, then watch the pipeline through to **Active**.
7. Open the environment's access URL. If you do not set a hostname, ZopDay derives
   one under the space's domain.

## Container facts

| Setting | Value |
|---|---|
| Base image | `nginx:1.27-alpine` |
| Listen port | `8080` (override with `PORT`) |
| Health endpoint | `/healthz` → `200 ok` |
| Custom 404 | yes (`404.html`) |
| Indexing | enabled — this is a public product page |
| Downloads | `Notchling.zip`, 5 minute cache |

## After it is live

Point these at the new hostname, then redeploy:

- `index.html` — `og:image` and `twitter:image`
- `get.sh` — the `Notchling.zip` download URL
- the app's own update check (`Sources/Notchling/main.swift` → `version.txt`)
- `promo/PRODUCT-HUNT.md`, `LAUNCH-CHECKLIST.md`, `promo/LAUNCH-SOCIAL.md`

Until then the site is live on Vercel at <https://notchling.vercel.app>.
