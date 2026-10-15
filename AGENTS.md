# MusicLink

## Purpose & links

- Shares songs between YouTube Music, Apple Music, Spotify and Deezer, no sign-up: SvelteKit web (`apps/web`), Hono API (`apps/api`), Flutter app with a share extension (`apps/mobile`).
- Live at https://musiclink.pleasance.org, Coolify on VPS 1, project `pleasance-musiclink`.
- Feedback button in web and app (bug with screenshot, ideas from the footer or the app settings), ported from `robinchoice/starter`. From 1.0 on (`LIVE` in `packages/shared`, `live` in the app's `config.dart`) the bug shows only in test mode, a switch kept per device in the web footer and the app settings; „Feedback geben“ stays for everyone. Reports land in Postgres and are mailed to `FEEDBACK_EMAIL`. The tester's email is optional; the Savor workflow „Weihnachtstester“ picks the most helpful testers from it.
- iOS: App Store Connect app `6819013473`, bundle `org.musiclink.prototype`. Signing material and TestFlight groups: `~/dev/kontor/infra.md`.

## Checks

```sh
cp -n .env.example .env && docker compose up -d   # Postgres on port 5439 for the API tests
bun install --frozen-lockfile && bun run check && bun run test   # test builds the web and tests the build
cd apps/mobile && flutter pub get && flutter analyze && flutter test   # when apps/mobile changed
```

The browser tests start the API and the production build of the web on their own ports (53100, 54100), never a running dev server. If another worktree tests at the same time, pick other ports: `TEST_API_PORT=53101 TEST_WEB_PORT=54101 bun run test`.

## Deploy

- A push to `main` runs `ci.yml`: checks, builds the images, then deploys them through the Coolify API.
- Pushes that touch `apps/mobile` also run `mobile.yml`, which uploads an iOS build to TestFlight and builds the Android bundle.
- Verify: `gh run watch`. The deploy job only turns green once `https://musiclink.pleasance.org/api/health` reports the commit as `revision`.
- Pushes to any branch and PRs from forks also run `secrets.yml`, the secret scan (see „Secret scan“).

## Pitfalls

- The bundle ID `org.musiclink.prototype` and the repo name predate the naming rules and stay as they are.
- The iOS app signs with explicit distribution profiles for the app and the share extension (secrets `IOS_CERTIFICATE_BASE64`, `IOS_APP_PROFILE_BASE64`, `IOS_SHARE_PROFILE_BASE64`). A new extension or capability needs new profiles.
- No GitHub issues for feedback: the repo is public, reports and screenshots would be too. They stay in the database and the mail.
- adapter-node accepts 512 KB request bodies by default. `Dockerfile.web` raises `BODY_SIZE_LIMIT`, otherwise app screenshots (PNG) fail with 413 at the web proxy.
- Share links (`/s/yt/<id>`, `/s/am/<country>/<id>`, `/s/sp/<id>`, `/s/dz/<id>`) and invite links (`/f/<service>?name=…`) carry everything they need and are out in chats. Keep both formats readable; `sharePath` in the API and `sourceLink` in the web share page must match.
- `spotify.link` short links are Branch links: the API reads the `spotify.app.link` page and takes the first `open.spotify.com/track/…` URL in it. If Branch changes that page, short links fail with `INVALID_LINK` while full links keep working.
- Friends and groups live only on the device: web in localStorage, app as one JSON string via the preferences channel (`getSocial`/`setSocial`), on iOS in the app group so the share extension reads the same list. The invite page opens the app with `musiclink://app/friend?name=…&service=…`, a plain URL scheme that needs no new signing profile. The API caches `/api/v1/song` results in memory for 24 hours; the privacy page says so.
- Link previews: the layout sets the `og:` tags, public pages override title, description and an absolute image (song covers) with `meta` from their load (`/s/…` server load, `/f/[service]` `+page.ts`). Crawlers run no JavaScript, so `meta` only works on SSR pages. The web is German only, so there is one picture, `static/og-image-de.png`: rerun `bun run og-image` in `apps/web` and commit it when `APP_NAME`, `APP_BAND`, `APP_TAGLINE` or the tile `static/favicon.svg` (same as `img/werkzeuge/musiclink.svg` in the pleasance repo) change. WhatsApp caches previews for a long time.
- Postgres holds feedback only. New table: change `packages/db/src/schema.ts`, `bun run --filter @app/db db:generate`; the migration runs on the next API start.

## Conventions

- Stateless, so MusicLink can move to another server or run replicated behind a load balancer (`infra.md`, „Skalierung“): disk and process memory hold no state that must outlive an instance or hold for all of them. Feedback and its rate limits live in Postgres, no volume besides `pgdata`. In-memory caches only if every instance may lose them, like the 24-hour song cache.
- No background jobs or timers (`setTimeout`, `setInterval`) in the API process. If one is needed, it runs as its own `worker` role like in starter.
- Every role has a health check in its image: API `/api/health`, web `/health` (process only).
- Config only through env: every new variable goes into `.env.example`, `.env.production.example` and `docker-compose.prod.yml`. No server domains, IPs or paths in the code.
- Postgres has a memory limit in the compose file (`POSTGRES_MEMORY`, default `512m`). If it gets tight, raise it in Coolify, don't remove it.
- Every migration must work with the old code still running: add columns nullable or with a default, rename and drop only in the deploy after.
- Status colours: errors use the fixed signal red (`--error`, glow on the dark ground) from starter's `DESIGN.md`, never the product colour.
- The repo is public, its CI logs too. `secrets.yml` scans every push and PR with gitleaks („Secret scan“). Catch false alarms narrowly, by fingerprint in `.gitleaksignore` or by path and rule in `.gitleaks.toml`, never turn a rule off. A real finding is public already: rotate the secret right away.
- No secrets in the client: everything in the web bundle and the app can be read, with LLMs from compiled apps too. Only the server decides what is allowed. Release builds of the app run with `--obfuscate --split-debug-info`, which makes them smaller and strips class and function names but protects nothing. No further obfuscation (string encryption, commercial tools). Symbolizing stack traces: „Release builds“.
- Readable for agents („For agents“): every static public page is in `publicPages` in `apps/api/src/lib/public-pages.ts`, in German and English, with its content as Markdown in `body`. A new public page goes in with the same change; the browser test checks that every listed page exists. Only what anyone sees without a shared link: no share pages (`/s/…`), no invites (`/f/…`).

## Secret scan

`.github/workflows/secrets.yml` runs on every push to every branch and on PRs from forks, without `paths-ignore`, and scans the new commits with gitleaks (Docker image pinned by digest). A finding turns the run red; `--redact` keeps the value out of the public log.

- Rules: the gitleaks defaults plus `.gitleaks.toml`, which only exempts `generic-api-key` in `bun.lock` and `apps/mobile/pubspec.lock`, where hashes trip it. Real token formats (`ghp_…`, `sk_live_…`) are still caught there.
- False alarm: add the `Fingerprint` from the log as a line to `.gitleaksignore`.
- Real finding: the scan runs after the push, so the secret is public already. Rotate it at once; removing it from the code or the history is not enough.
- Locally over the whole history: `docker run --rm -v "$PWD:/repo" <image from secrets.yml> git /repo --no-banner --redact`.

## For agents

Other people's agents read the public pages without HTML, after [llms.txt](https://llmstxt.org). Source is `publicPages` in `apps/api/src/lib/public-pages.ts`, the routes are in `apps/api/src/routes/agents.ts`, and `hooks.server.ts` in the web forwards the paths to the API.

- `/llms.txt`: name, tagline and every public page as a link to its Markdown. `/llms-full.txt`: all pages in one file.
- `<page>.md`: every page as Markdown, the start page as `/index.md`. A request with `Accept: text/markdown` for a page that has Markdown gets it under the same URL, everyone else the HTML.
- Language: `?lang=de|en`, else `Accept-Language`, else German. Links keep an explicit `?lang=`. The English legal pages (`/imprint`, `/privacy`) answer in English without it.
- The API builds the links from `APP_URL`. Try it: `curl localhost:5173/llms.txt` with `bun run dev` running.

## Release builds

Release builds of the app (`mobile.yml`) are built with `--obfuscate`, so stack traces from the app, in GlitchTip too, only show obfuscated names. The symbols are kept for 90 days as the artifacts `symbols-ios` and `symbols-android` of the CI run; the app's build number is that run's number (`gh run list -w mobile.yml --json number,databaseId` gives the run ID). To read a trace:

```sh
gh run download <run-id> -n symbols-android -D /tmp/symbols
flutter symbolize -i trace.txt -d /tmp/symbols/app.android-arm64.symbols   # iOS: app.ios-arm64.symbols
```

`trace.txt` is the raw stack trace with `build_id` and `abs …/virt …` lines (e.g. from `adb logcat`). Builds older than 90 days can no longer be symbolized.

## Abweichungen vom Standard

- The converter throttle in `app.ts` (60 lookups per minute) counts in process memory, not in Postgres: it guards the upstream services' per-IP limits, so a count per instance is right, and the converter runs without a database.
- Signal colours: only the error signal, MusicLink has no „your turn“ or „new“ states.
- No README: the sections „Secret scan“, „For agents“ and „Release builds“, which starter keeps in its README, are here.
- The legal pages are not copied into `publicPages` as Markdown: their Markdown has title, description and a link to the HTML page, so there is only one binding version of Impressum and Datenschutz.
