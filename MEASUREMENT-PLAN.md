# Measurement plan — container-deploy-lab

How to run the deploys behind the article *My Container Deploy Failed. How to Read the Log and Fix It*, what to capture for each branch, and where the numbers go. Everything below happens in the Back4app dashboard and a terminal; the repository is ready and every branch is pushed.

## 0. Before the first deploy

- Repository: `https://github.com/templates-back4app/container-deploy-lab`, branches `main` and eight `break/*` branches (`git branch -r` lists them).
- The *Back4App Containers* GitHub App must be able to see this repository. The installation on the `templates-back4app` organisation is managed by an organisation owner (GitHub → organisation Settings → GitHub Apps → Back4App Containers → Repository access → add `container-deploy-lab`). If the repo does not show up in the dashboard's repo picker, that list is the reason. Do the install or the *Import GitHub Repo* step in the same browser where the dashboard is logged in; a callback that lands in a logged-out browser leaves the picker at "Nothing here, yet!".
- **One container app per branch**, named `lab-<branch>` (`lab-main`, `lab-wrong-port`, …). Reason: the wrong-port deploy writes the detected port into the app's settings ("Port 3000 saved to the app settings for future deploys"), which would alter the next branch's run on a shared app. Separate apps also keep each deployment log and Runtime Logs page clean for screenshots.
- Free plan quota shows as *N / 50* apps; nine apps fit. Each free deploy gets a **60-minute temporary URL**, counted from the moment the deploy starts, then the status turns to *URL Expired* and the deployment is destroyed. Capture everything for a branch within the hour; a redeploy restarts the window.
- Deploy `main` first. It is the control: its log is the reference every failing log is compared against, and it proves the account and the GitHub App work before anything is deliberately broken.
- Terminal: keep a poller running from the moment of the Deploy click so the first HTTP status is timestamped independently of the dashboard (`URL` is shown on the app's Overview before the deploy finishes):

  ```bash
  URL=https://<app>.b4a.run
  while true; do printf '%s  ' "$(date -u +%H:%M:%S)"; curl -s -o /dev/null -m 5 -w '%{http_code}\n' "$URL/healthz"; sleep 5; done | tee /tmp/<branch>-poll.log
  ```

  Then `./deploy-check.sh $URL` once the dashboard says READY (or once the poller shows a status), and keep its output.

## 1. Steps per branch (the same nine times)

1. **Containers → New App → Deploy from GitHub.** Select `container-deploy-lab`.
2. Form: **App name** `lab-<branch>`; **Branch** the branch under test; build method should read *Dockerfile* (detected); **Port** empty (the platform reads `EXPOSE`; for `break/no-expose` note what the field shows or suggests when there is nothing to read); **Health check** `/healthz`; **Environment variables** none, except `break/missing-env` on its second deploy (below).
3. Note the wall-clock time (seconds) and click **Deploy**. Start the poller if it is not already running.
4. Watch the deployment log. Record the time each phase line appears: `PREPARING`, `FETCHING GITHUB REPOSITORY`, `BUILDING IMAGE`, `Pushed image`, `LAUNCHING CONTAINER`, `CHECKING HEALTH`, `DEPLOYMENT READY` or the failure line, and any auto-detect lines between them.
5. When the status settles, capture (list in §2), run `./deploy-check.sh`, and open **Runtime Logs**.
6. Apply the branch's fix where the plan says so (§3), redeploy, and time the fixed deploy too. That second number is the "time to fix" the article can quote.

## 2. What to capture for every branch

- **Deployment log, full text.** Select-all and copy into `notes/<branch>-deploy-log.txt` (outside the repo, e.g. the session scratchpad); the article quotes the exact lines. Also a screenshot of the log panel, 1600 px JPEG, named `NN-<branch>-deploy-log.jpg`.
- **Status badge** on the app's Overview and in the Deployments list, exact wording (`Available`, `Ready`, `Failed`, `Destroying`, `URL Expired`, …) and its colour.
- **Timings:** Deploy click → first phase line; → `Pushed image` (build time; the Overview also shows *Ready in NN s* for the build); → `DEPLOYMENT READY` or the failure line; → first HTTP status from the poller. Stopwatch precision is seconds; say so in the "How we measured" sentence.
- **The image line.** Whatever the log prints at `Pushed image` (size, layers, digest). If the dashboard shows an image size anywhere, capture it; the CI workflow's uncompressed size is the fallback (§4).
- **Runtime Logs:** the container's stdout/stderr lines, tagged SYSTEM or ERROR, with the container id. For crash-at-start branches this is where the Node stack trace lives, and whether the platform restarts the container (count the repeated `listening`/error lines and their timestamps: restart loop, or one attempt and stop?).
- **The port field** in Settings after the deploy (for the two port branches: did the platform save a port, and which?).
- `./deploy-check.sh` output and exit code.
- Anything the *Finish your setup* review dialog suggests on a redeploy (start command, port) for that branch.

Screenshots: only of things you ran; blur the account e-mail if it appears in the top bar. App ids and `b4a.run` URLs were shown unblurred in the previous Containers posts.

## 3. Per-branch specifics

| Branch | What to look for | Fix to apply and redeploy |
|---|---|---|
| `main` | The clean log, all phases, the build time, the image line. Reference for everything else. | — |
| `break/wrong-port` | Expected (documented 2026-09-10): `App is not listening on port 8080, but on port 3000 — switching to it (auto-detected)` then `Port 3000 saved to the app settings for future deploys` then `DEPLOYMENT READY`. Confirm the wording, and whether Settings now shows 3000. | No code fix needed for the article's point; optionally redeploy `main` on the same app to show the saved 3000 being switched back. |
| `break/missing-dependency` | Build passes (`npm ci` uses the lockfile, which has no `dayjs`). At launch: `Error: Cannot find module 'dayjs'` + `Require stack:` in Runtime Logs. Which phase the deployment log fails in (`LAUNCHING CONTAINER` or `CHECKING HEALTH`), the exact failure line, and whether the container is restarted. | Add `dayjs` locally (`npm install dayjs`), commit `package.json` + lockfile on the branch, push, *Deploy latest commit*, time it. Or point the same app at `main`. |
| `break/bad-start-command` | `Error: Cannot find module '/app/index.js'` in Runtime Logs; failure phase and line in the deployment log. Also try **Settings → start command** override to `node server.js` if the dashboard offers one: does a dashboard setting beat `CMD`? | Dashboard start-command override if available (time it); otherwise point the app at `main`. |
| `break/missing-env` | `Error: REQUIRED_SECRET is not set (Settings → Environment)` in Runtime Logs; failure phase. | **Settings → Environment** → add `REQUIRED_SECRET=anything` → the dashboard offers *Deploy now*; time from that click to READY. This is the branch's real measurement: a fix with no commit. |
| `break/health-check-path` | Known (2026-09-15): a health path that returned 404 still passed, so the check looks like a port probe. Does a 500 pass too? Record status, log lines in `CHECKING HEALTH`, and `deploy-check.sh` failing on the 500 while the badge says Ready. Optional second test: set the health check path to `/does-not-exist`. | None; the finding is the point. If the deploy fails instead, capture the exact line — that would correct the earlier note. |
| `break/dockerfile-syntax` | Fails in `BUILDING IMAGE`. Capture the builder's error text verbatim (kaniko names the file it could not `lstat`) and note that no `LAUNCHING CONTAINER` line ever appears. Time to the failure line (fast fail is the useful number). | Point the app at `main` or remove the `COPY` line on the branch and push. |
| `break/no-expose` | The form's port field with nothing to read; then the log. The app listens on 4000 and ignores `PORT`, so an auto-detect line `App is not listening on port X, but on port 4000` reveals X = the platform's default with no `EXPOSE`. If no auto-detect happens, capture how it fails. | Set the port to 4000 in Settings and redeploy, or point the app at `main`. |
| `break/big-image` | Build time and image size vs `main` (same app code, `node:22` instead of `node:22-alpine`). `Pushed image` line, *Ready in NN s*, click → READY. Run it twice if time allows: first build and a cached rebuild. | None; the comparison is the result. |

## 4. Secondary numbers from CI (no dashboard needed)

`.github/workflows/image.yml` runs on every push to every branch: `docker build --no-cache`, then prints the image's uncompressed size in bytes and MB to the job summary, then starts the container and curls `/healthz` on 8080. Actions → *image* → pick the branch's run. Use it for:

- uncompressed image size, `main` vs `break/big-image` (the platform's `Pushed image` line, if it shows a size, is compressed; label the two differently);
- a second opinion on which step fails locally for each branch (build vs run vs health) — a GitHub runner, not the platform, so quote it only as "on a GitHub Actions runner".

First results, September 24, 2026 (one run per branch, `ubuntu-latest`): `main` 163 MB / 11 s; `break/big-image` 1,083 MB / 24 s (6.6× the size, about 2× the build); `break/dockerfile-syntax` failed in the build step with `"/config/settings.json": not found` (BuildKit wording — the platform's builder is kaniko, so expect a different sentence for the same cause); the three crash-at-start branches passed the build and exited before the smoke curl; the two port branches passed the build, logged `listening on 3000` / `listening on 4000`, and the curl to 8080 was reset; `break/health-check-path` answered `500` to the smoke curl. Other branches' builds ranged 6–13 s on the same base image, which is runner noise, not a signal.

## 5. Results table (fill in; copy into the article and the README)

| Branch | Build | Status badge | Click → READY / failure | First HTTP status (poller) | Log line that names the problem | Fix → READY |
|---|---|---|---|---|---|---|
| `main` | | | | | — | — |
| `break/wrong-port` | | | | | | |
| `break/missing-dependency` | | | | | | |
| `break/bad-start-command` | | | | | | |
| `break/missing-env` | | | | | | |
| `break/health-check-path` | | | | | | |
| `break/dockerfile-syntax` | | | | | | |
| `break/no-expose` | | | | | | |
| `break/big-image` | | | | | | |

Columns: *Build* = pass/fail and seconds from the `Ready in NN s` figure or the log; *Status badge* = exact wording; *Click → READY / failure* = stopwatch seconds; *First HTTP status* = first non-timeout code the poller saw and the time; *Fix → READY* = seconds from the fix's Deploy click, where a fix was applied.

## 6. Known platform facts to rely on (do not re-measure unless something contradicts them)

- Deployment log phases on a clean deploy: `PREPARING → FETCHING GITHUB REPOSITORY → BUILDING IMAGE → Pushed image → LAUNCHING CONTAINER → CHECKING HEALTH → DEPLOYMENT READY` (2026-09-10, link-shortener: 42 s click → first 200, 29 s of it the build; image 64.6 MB compressed, 8 layers).
- Wrong port: not a failure. The platform probes, logs `App is not listening on port 8080, but on port 3000 — switching to it (auto-detected)`, saves the port to the app settings and reports READY (2026-09-10).
- Health check: a path that returned 404 passed (2026-09-15), i.e. the check behaves like a port probe. `break/health-check-path` tests the 500 case.
- Free plan since 2026-09-15: temporary URL for 60 minutes per deploy, then *URL Expired* and the deployment is destroyed; auto deploy is disabled; 0.25 vCPU / 256 MB. Paid Shared plans from $5/month give a permanent URL.
- *Deploy latest commit* opens a *Finish your setup* review first (detected stack, suggested start command and port); *Deploy without changes* starts the build.
- Environment variable changes apply on the next deploy; the dashboard offers *Deploy now* after saving.
- Redeploys keep the old container serving until the new one is Ready (zero failed requests measured across four swaps, 2026-09-10).
- Runtime Logs show stdout as SYSTEM and stderr as ERROR, tagged with the container id.
- The proxy terminates TLS and does not forward the scheme (`req.protocol` is `http`). Not relevant to this lab's routes, but do not be surprised by it.
- The image-based deploy route accepts Docker Hub references only (2026-09-10).

## 7. Screenshots the article will want (1600 px JPEG, `public/blog-assets/<slug>/`)

1. `main` deployment log, all phases, with the Overview badge *Available*.
2. `break/wrong-port` log with the two auto-detect lines.
3. `break/missing-dependency` Runtime Logs with `Cannot find module 'dayjs'` and the Require stack.
4. `break/bad-start-command` Runtime Logs with `Cannot find module '/app/index.js'`.
5. `break/missing-env` Runtime Logs, then Settings → Environment with `REQUIRED_SECRET` and the *Deploy now* prompt.
6. `break/health-check-path` Overview showing Ready next to a terminal with `deploy-check.sh` failing.
7. `break/dockerfile-syntax` log stopping in `BUILDING IMAGE` with the builder error.
8. `break/no-expose` the form's port field, then the log's auto-detect line.
9. `break/big-image` and `main` build timings side by side (Deployments list or Overview *Ready in NN s*).
