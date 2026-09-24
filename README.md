# container-deploy-lab

[![Deploy on Back4app](https://img.shields.io/badge/Deploy%20on-Back4app-1568B8?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJMMiA3djEwbDEwIDUgMTAtNVY3eiIvPjwvc3ZnPg==)](https://www.back4app.com/signup?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab)

**One Node.js app that deploys cleanly on Back4app Containers, and eight git branches that each break the deploy in exactly one way.** `main` is 20 lines of Express and an 8-line Dockerfile on `node:22-alpine`. Every `break/*` branch changes the minimum needed to produce one specific failure, so you can put the log line the dashboard shows next to a known cause and a known fix. Built for [Back4app](https://www.back4app.com/) Containers; nothing here needs a server of your own.

Measured on Back4app Containers, free plan: the table under *What we measured* is filled from the deploys of each branch, with the exact deployment-log line and the time from the Deploy click to `DEPLOYMENT READY` or the failure.

> **Read the article:** [My Container Deploy Failed. How to Read the Log and Fix It](https://www.back4app.com/blog/my-container-deploy-failed-how-to-read-the-log-and-fix-it?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab)

## What is in here

- `server.js` — the app: `GET /` prints the version, the port and the Node version; `GET /healthz` answers `{"ok":true}`; it listens on `process.env.PORT || 8080`.
- `Dockerfile` — 8 lines, `node:22-alpine`, `npm ci --omit=dev`, `EXPOSE 8080`, `CMD ["node", "server.js"]`.
- `deploy-check.sh` — verifies a deployment: health, then root. Exits non-zero if either is off.
- `MEASUREMENT-PLAN.md` — how each branch is deployed and measured, and what gets captured.
- `.github/workflows/image.yml` — builds the Dockerfile of every pushed branch, prints the image size, then starts the container and hits `/healthz`. On a `break/*` branch one of the three steps is supposed to go red.

## The branches

Every branch is `main` plus one change. `git diff main..break/<name>` shows exactly what broke.

| Branch | What is broken | Where | What to expect |
|---|---|---|---|
| `main` | Nothing | — | `DEPLOYMENT READY`, `/healthz` → 200 |
| `break/wrong-port` | App listens on 3000, Dockerfile says 8080 | `server.js` | Log: *App is not listening on port 8080, but on port 3000 — switching to it*; deploys anyway |
| `break/missing-dependency` | `server.js` requires `dayjs`, `package.json` does not list it | `server.js` | Build passes, container exits at start: `Cannot find module 'dayjs'` |
| `break/bad-start-command` | `CMD` runs `index.js`, which does not exist | `Dockerfile` | Container exits at start: `Cannot find module '/app/index.js'` |
| `break/missing-env` | App throws at boot when `REQUIRED_SECRET` is unset | `server.js` | Container exits at start: `REQUIRED_SECRET is not set`; fixed from Settings → Environment |
| `break/health-check-path` | `/healthz` returns 500 | `server.js` | Tests whether the health check reads the status code or only the port |
| `break/dockerfile-syntax` | `COPY` of a file that is not in the repo | `Dockerfile` | Build fails before any container runs |
| `break/no-expose` | No `EXPOSE`, app listens on a fixed 4000 and ignores `PORT` | `Dockerfile`, `server.js` | Shows which port the platform assumes when the Dockerfile gives no hint |
| `break/big-image` | `node:22` (Debian, with gcc, g++, make and python3) instead of `node:22-alpine` | `Dockerfile` | Same app, several times the image; measures build time and size |

### `break/wrong-port` — the app ignores the port the platform expects

`server.js` sets `const PORT = 3000;` and no longer reads `process.env.PORT`. The Dockerfile still says `EXPOSE 8080`, so the platform starts by probing 8080. Measured on September 10, 2026 for a sibling repo: the deployment log printed `App is not listening on port 8080, but on port 3000 — switching to it (auto-detected)` and `Port 3000 saved to the app settings for future deploys`, then `DEPLOYMENT READY`. A port mismatch is not a failure on this platform; it is a setting that changes under you. The fix is to read `process.env.PORT`, as `main` does.

### `break/missing-dependency` — the code needs a module the lockfile does not have

`server.js` does `const dayjs = require("dayjs")` and prints the date on `/`. `package.json` and `package-lock.json` are untouched, so `npm ci --omit=dev` succeeds and the image builds. The container then exits on its first line with `Error: Cannot find module 'dayjs'` and a `Require stack` pointing at `/app/server.js`. Expect the build to pass and the launch or health phase to fail. The fix is `npm install dayjs` and committing both `package.json` and `package-lock.json`.

### `break/bad-start-command` — `CMD` points at a file that is not there

The Dockerfile ends with `CMD ["node", "index.js"]`; the file is `server.js`. The image builds, the container starts, Node exits with `Error: Cannot find module '/app/index.js'`. The same message appears when `WORKDIR` and `COPY` disagree about where the file went. The fix is the file name in `CMD`, or `npm start` with the right `start` script.

### `break/missing-env` — the app refuses to boot without a variable

`server.js` throws `Error: REQUIRED_SECRET is not set (Settings → Environment)` before `app.listen`. A first deploy without the variable exits at start; the fix is a one-line addition under **Settings → Environment** followed by the *Deploy now* the dashboard offers. The branch also shows the second half of the story: a variable saved after the deploy does nothing until the next deploy.

### `break/health-check-path` — the health endpoint answers 500

`/healthz` returns `500 {"ok":false,"reason":"simulated dependency failure"}` while `/` keeps working. What this tests: on September 15, 2026 the platform's health check passed a container whose health path returned 404, which suggests the check is a port probe, not an HTTP status check. If that holds, this branch reports `DEPLOYMENT READY` and `./deploy-check.sh` is the only thing that catches it, because `curl -f` fails on the 500.

### `break/dockerfile-syntax` — the build fails before the app exists

The Dockerfile adds `COPY config/settings.json ./` and there is no `config/` directory. The build stops during `BUILDING IMAGE` with an error from the builder naming the missing path; no container is launched, no health check runs. The fix is to remove the line or commit the file, and to look at `.dockerignore` when the file is in the repo but still missing at build time.

### `break/no-expose` — the Dockerfile gives no hint at all

The Dockerfile has no `EXPOSE`, and `server.js` listens on a fixed `4000` without reading `PORT`. 4000 was chosen because it is neither the Dockerfile default nor anything the platform could guess, so whatever the platform probes first shows up in the auto-detect line and tells you the default it assumes. The fix is `EXPOSE` plus `process.env.PORT`.

### `break/big-image` — the same app on a base image with a compiler in it

The only change is `FROM node:22`, the default tag: Debian bookworm with gcc, g++, make and python3 preinstalled, none of which this app needs. It builds and deploys; the difference is in the `BUILDING IMAGE` and `Pushed image` timings and in the image size. `.github/workflows/image.yml` prints the uncompressed size of every branch's image on each push, so the two numbers can be compared without the dashboard.

## What we measured

**On a GitHub Actions runner** (`.github/workflows/image.yml`, `docker build --no-cache`, September 24, 2026): the healthy image is **163 MB** uncompressed and builds in **11 s**; the same app on `node:22` is **1,083 MB** and builds in **24 s**. One run per branch, sizes from `docker image inspect`, seconds from a `date` diff around `docker build`; runner speed varies, so read the ratio, not the seconds.

| Branch | Build (no cache) | Image, uncompressed | Step that fails on the runner |
|---|---|---|---|
| `main` | 11 s | 163 MB | none — `/healthz` → `{"ok":true}` |
| `break/wrong-port` | 11 s | 163 MB | Smoke run: app logs `listening on 3000`, curl to 8080 is reset |
| `break/missing-dependency` | 11 s | 163 MB | Smoke run: container exits at start |
| `break/bad-start-command` | 13 s | 163 MB | Smoke run: container exits at start |
| `break/missing-env` | 6 s | 163 MB | Smoke run: container exits at start |
| `break/health-check-path` | 8 s | 163 MB | Smoke run: `curl: (22) The requested URL returned error: 500` |
| `break/dockerfile-syntax` | fails | — | Build: `"/config/settings.json": not found` |
| `break/no-expose` | 6 s | 163 MB | Smoke run: app logs `listening on 4000`, curl to 8080 is reset |
| `break/big-image` | 24 s | 1,083 MB | none — same app, 6.6× the image |

**On Back4app Containers:** filled from the deploys of each branch; the article carries the same table with the log excerpts.

| Branch | Build | Status after deploy | Click → READY / failure | Log line that names the problem |
|---|---|---|---|---|
| `main` | | | | |
| `break/wrong-port` | | | | |
| `break/missing-dependency` | | | | |
| `break/bad-start-command` | | | | |
| `break/missing-env` | | | | |
| `break/health-check-path` | | | | |
| `break/dockerfile-syntax` | | | | |
| `break/no-expose` | | | | |
| `break/big-image` | | | | |

## Deploy your own

1. **Create a free account.** Sign up at [https://www.back4app.com/signup?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab](https://www.back4app.com/signup?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab). The free Containers plan (0.25 vCPU, 256 MB) is enough for every branch here.
2. **Fork or push this repository** to your GitHub account. Keep the branches: the dashboard lets you pick one per app.
3. **Containers → New App → Deploy from GitHub → Import GitHub Repo.** Install the *Back4App Containers* GitHub App on this repository, in the same browser where you are logged into the dashboard, then **Select** the repo.
4. **Configure:** name the app after the branch (`lab-main`, `lab-wrong-port`, …), pick the **branch**, leave the port empty (the platform reads `EXPOSE`), set the health check to `/healthz`, add no environment variables except where the branch says so. **Deploy.**
5. **Read the log.** The deployment log goes `PREPARING → FETCHING GITHUB REPOSITORY → BUILDING IMAGE → Pushed image → LAUNCHING CONTAINER → CHECKING HEALTH → DEPLOYMENT READY` on `main`; on a `break/*` branch it stops at the phase the branch breaks. Runtime Logs show the container's stdout and stderr.
6. **Verify:** `./deploy-check.sh https://<your-app>.b4a.run`

Use one app per branch. The `break/wrong-port` deploy writes the detected port into that app's settings, which would change what the next branch sees if they shared an app. On the free plan a container's URL lives 60 minutes per deploy (since September 15, 2026); a redeploy restarts the window.

## Run locally

```bash
npm ci --omit=dev
node server.js                          # listening on 8080
./deploy-check.sh http://localhost:8080
```

With Docker installed, the same image the platform builds:

```bash
docker build -t container-deploy-lab .
docker run --rm -p 8080:8080 container-deploy-lab
```

To reproduce a failure locally, `git switch break/<name>` and run the same commands; the error you get is the one the platform's log shows.

## What the platform gives you

Containers build the Dockerfile from a GitHub branch, run the image behind HTTPS on a public URL, write the deployment log and the container's output to the dashboard, and redeploy on click (or on push, on paid plans). Documentation: [https://www.back4app.com/docs-containers?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab](https://www.back4app.com/docs-containers?utm_source=github&utm_medium=repo&utm_campaign=container-deploy-lab).

## License

MIT
