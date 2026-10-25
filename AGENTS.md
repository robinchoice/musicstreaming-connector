# Songgate

## Purpose & links

- Shares songs between YouTube Music, Apple Music, Spotify and Deezer, no sign-up: SvelteKit web (`apps/web`), Hono API (`apps/api`), CLI `songgate` (`apps/cli`, „CLI“), Flutter app with a share extension (`apps/mobile`).
- Live at https://songgate.app, Coolify on VPS 1, project `pleasance-musiclink`.
- Feedback button in web and app (bug with screenshot, ideas from the footer or the app settings), ported from `robinchoice/starter`. From 1.0 on (`LIVE` in `packages/shared`, `live` in the app's `config.dart`) the bug shows only in test mode, a switch kept per device in the web footer and the app settings; „Feedback geben“ stays for everyone. Reports land in Postgres and are mailed to `FEEDBACK_EMAIL`. The tester's email is optional; the Savor workflow „Weihnachtstester“ picks the most helpful testers from it.
- iOS: App Store Connect app `6819013473`, bundle `org.musiclink.prototype`. Signing material and TestFlight groups: `~/dev/kontor/infra.md`.

## Checks

```sh
cp -n .env.example .env && docker compose up -d   # Postgres on port 5439 for the API tests
bun install --frozen-lockfile && bun run check && bun run test   # test builds the web and tests the build, plus the CLI against the API
cd apps/cli && bun run build   # when apps/cli changed, compiles build/songgate
cd apps/mobile && flutter pub get && flutter analyze && flutter test   # when apps/mobile changed
# On macOS (also runs in mobile.yml):
swiftc -parse-as-library ios/ShareExtension/ShareModel.swift test/share_targets.swift -o /tmp/musiclink-share-targets-test && /tmp/musiclink-share-targets-test
```

The browser tests start the API and the production build of the web on their own ports (31100, 31101), never a running dev server. Keep test ports below Linux's ephemeral range (32768–60999), so outgoing connections cannot occupy them. If another worktree tests at the same time, pick other ports: `TEST_API_PORT=31102 TEST_WEB_PORT=31103 bun run test`.

`bun run test` gives the API and browser suites their own empty temporary database on the server from `DATABASE_URL`. The user needs `CREATEDB` (local Compose and CI already have it). The runner deletes only that database on success, failure or SIGINT/SIGTERM; direct `bun test` or `playwright test` calls bypass isolation.

## Deploy

- A push to `main` runs `ci.yml`: checks, builds the images, then deploys them through the Coolify API.
- After a successful deploy, `screenshots` photographs the public home page in fresh browser contexts (German, desktop 1440×900 and phone 390×844 at double density). No login, shared links, query parameters or user data. The starter script `apps/web/screenshots.ts` replaces `docs/screenshots/` with WebP images, so only the current set is kept. Run locally with `bun run screenshots [url]` in `apps/web`.
- Changed screenshots are committed to `main` by `github-actions[bot]` with `[skip ci]` to prevent deploy loops. Fetch before pushing. Only after the screenshots succeed, the job sends `prototype-deployed` (`client_payload: {slug, sha}`) to `robinchoice/pleasance` using the existing `PLEASANCE_DISPATCH_TOKEN` secret, scoped to that receiver. Without the secret only the dispatch is skipped.
- Pushes that touch `apps/mobile` also run `mobile.yml`, which uploads an iOS build to TestFlight and builds upload-key-signed Android AAB and APK artifacts (kept for 90 days). Android release CI requires the `ANDROID_KEYSTORE_*`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` secrets. Robin confirmed `org.pleasance.songgate` on 22 October 2026. After he uploads the first AAB manually and grants the service account access, set `PLAY_SERVICE_ACCOUNT_JSON` and `PLAY_UPLOAD=true` to upload subsequent builds to Play internal testing. Never enable this before package-name confirmation; no production promotion runs automatically. Job `testflight` (`apps/mobile/tool/testflight.mjs`) gives every build to the internal group „MusicLink Internal“.
- External testers (group „MusicLink V1“) don't get every build: TestFlight mails a group's testers for each build it is given. Only the build of a release tag `v*` goes there and is submitted for the beta review, and an agent sets that tag only when Robin asks for a release. `git tag v<version> && git push origin v<version>` builds iOS and Android again and releases that build. An already uploaded build: `node tool/testflight.mjs [--quiet] <build number> "MusicLink Internal" "MusicLink V1"` in `apps/mobile` with `ASC_*` from `~/.secrets`.
- Update requirement: app builds send `X-App-Platform` and `X-App-Build` (the CI run number, `BUILD_NUMBER`). Below `MIN_BUILD_IOS`/`MIN_BUILD_ANDROID` (Coolify, empty = no minimum) the API answers 426 except for feedback; the app then shows only the update screen with the store link, the share extension the message. Raise a minimum only once a newer build is live in that store. Web and builds older than the update screen send nothing and are never blocked.
- Verify: `gh run watch`. The deploy job only turns green once `https://songgate.app/api/health` reports the commit as `revision`.
- Pushes to any branch and PRs from forks also run `secrets.yml`, the secret scan (see „Secret scan“).

## Pitfalls

- Gitleaks 8.30.1 reads the checkout's `.gitleaksignore` in addition to `--gitleaks-ignore-path`. The workflow replaces it with `CONFIG_REF`'s version too; fork PRs use the base commit's config and ignores.
- Correlated subselects in `sql` templates: in a single-table select Drizzle renders columns without table names, including inside templates. `exists (select 1 from ${subs} where ${subs.userId} = ${users.id})` becomes `where "user_id" = "id"`, silently referring to the subselect's ID. Use a join or `alias()`, or two simple queries.

- The bundle ID `org.musiclink.prototype` and the repo name predate the naming rules and stay as they are. The old `musiclink.pleasance.org` host redirects to `songgate.app` with paths and queries intact; `/api` stays on the old host for installed app builds (POST requests must not be redirected). `www.songgate.app` redirects to the apex. The rules live on VPS 1 in `/data/coolify/proxy/dynamic/musiclink-redirect.yaml`.
- Apple may report a build as `VALID` before TestFlight group assignment can resolve its ID (404). Once the build is readable, rerun only the failed `testflight` job; do not upload the same build number again.
- The iOS app signs with explicit distribution profiles for the app and the share extension (secrets `IOS_CERTIFICATE_BASE64`, `IOS_APP_PROFILE_BASE64`, `IOS_SHARE_PROFILE_BASE64`). A new extension or capability needs new profiles.
- No GitHub issues for feedback: the repo is public, reports and screenshots would be too. They stay in the database and the mail.
- adapter-node accepts 512 KB request bodies by default. `Dockerfile.web` raises `BODY_SIZE_LIMIT`, otherwise app screenshots (PNG) fail with 413 at the web proxy.
- Share links (`/s/yt/<id>`, `/s/am/<country>/<id>`, `/s/sp/<id>`, `/s/dz/<id>`) and invite links (`/f/<service>?name=…`) carry everything they need and are out in chats. Keep both formats readable; `sharePath` in the API and `sourceLink` in the web share page must match.
- With `APPLE_MUSIC_*` set (MusicKit key, `infra.md`), an Apple Music or Deezer source is matched to the other by its ISRC through the Apple Music API and Deezer's `track/isrc:`. Every other source, and an ISRC without a hit, uses title, artist and duration. A failed ISRC lookup reports `ISRC lookup failure` to GlitchTip, most likely a revoked key.
- `spotify.link` short links are Branch links: the API reads the `spotify.app.link` page and takes the first `open.spotify.com/track/…` URL in it. If Branch changes that page, short links fail with `INVALID_LINK` while full links keep working.
- Friends and groups live only on the device: web in localStorage, app as one JSON string via the preferences channel (`getSocial`/`setSocial`), on iOS in the app group so the share extension reads the same list. The invite page opens the app with `musiclink://app/friend?name=…&service=…`, a plain URL scheme that needs no new signing profile. The API caches `/api/v1/song` results in memory for 24 hours; the privacy page says so.
- Link previews: the layout sets the `og:` tags, public pages override title, description and an absolute image (song covers) with `meta` from their load (`/s/…` server load, `/f/[service]` `+page.ts`). Crawlers run no JavaScript, so `meta` only works on SSR pages. The web is German only, so there is one picture, `static/og-image-de.png`: rerun `bun run og-image` in `apps/web` and commit it when `APP_NAME`, `APP_BAND`, `APP_TAGLINE` or the tile `static/favicon.svg` (same as `img/werkzeuge/musiclink.svg` in the pleasance repo) change. WhatsApp caches previews for a long time.
- Postgres holds feedback only. New table: change `packages/db/src/schema.ts`, `bun run --filter @app/db db:generate`; the migration runs on the next API start.

## Conventions

- Strict TypeScript: `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `noFallthroughCasesInSwitch`; Biome forbids `any` (`noExplicitAny`, `noImplicitAnyLet`, `noEvolvingTypes`). Unknown input stays `unknown` until parsed with zod: request bodies, external JSON, saved preferences and env in `apps/api/src/env.ts` (imported first at boot). Schemas passed to library types use `.exactOptional()`. Fix type errors at their source, without casts or suppression comments.
- On SIGTERM/SIGINT the API finishes startup, drains requests and closes its database pool. Compose allows 30 seconds; mail connections have bounded timeouts. There is no worker role.

- Stateless, so Songgate can move to another server or run replicated behind a load balancer (`infra.md`, „Skalierung“): disk and process memory hold no state that must outlive an instance or hold for all of them. Feedback and its rate limits live in Postgres, no volume besides `pgdata`. In-memory caches only if every instance may lose them, like the 24-hour song cache.
- No background jobs or timers (`setTimeout`, `setInterval`) in the API process. If one is needed, it runs as its own `worker` role like in starter.
- Every role has a health check in its image: API `/api/health`, web `/health` (process only).
- Config only through env: every new variable goes into `.env.example`, `.env.production.example` and `docker-compose.prod.yml`. No server domains, IPs or paths in the code.
- Postgres has a memory limit in the compose file (`POSTGRES_MEMORY`, default `512m`). If it gets tight, raise it in Coolify, don't remove it.
- Every migration must work with the old code still running: add columns nullable or with a default, rename and drop only in the deploy after.
- Status colours: errors use the fixed signal red (`--error`, glow on the dark ground) from starter's `DESIGN.md`, never the product colour.
- The repo is public, its CI logs too. `secrets.yml` scans every push and PR with gitleaks („Secret scan“). Catch false alarms narrowly, by fingerprint in `.gitleaksignore` or by path and rule in `.gitleaks.toml`, never turn a rule off. A real finding is public already: rotate the secret right away.
- No secrets in the client: everything in the web bundle and the app can be read, with LLMs from compiled apps too. Only the server decides what is allowed. Release builds of the app run with `--obfuscate --split-debug-info`, which makes them smaller and strips class and function names but protects nothing. No further obfuscation (string encryption, commercial tools). Symbolizing stack traces: „Release builds“.
- CLI („CLI“): every core feature gets a command in `apps/cli/src/commands` in the same change, like `convert.ts`, with text, `--json` and a test in `cli.test.ts`. The CLI talks only to the HTTP API, never to the database, so the converter throttle holds for it too.
- Readable for agents („For agents“): every static public page is in `publicPages` in `apps/api/src/lib/public-pages.ts`, in German and English, with its content as Markdown in `body`. A new public page goes in with the same change; the browser test checks that every listed page exists. Only what anyone sees without a shared link: no share pages (`/s/…`), no invites (`/f/…`).

## Secret scan

`.github/workflows/secrets.yml` runs on every branch/tag push and on PRs from forks, without `paths-ignore`, and scans new commits including merge resolutions with gitleaks (Docker image pinned by digest). Fork PRs use the base commit’s config and ignores; new branches/tags without new commits are skipped. A finding turns the run red; `--redact` keeps the value out of the public log.

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

## CLI

`apps/cli` is Songgate on the command line, so agents, scripts and tests use the converter by command instead of the UI. Like web and app it talks only to the public HTTP API (`POST /api/v1/convert`, `GET /api/v1/song`), with the same per-process throttle. `parseArgs` from `node:util` reads the arguments, no further dependency.

- Build: `bun run build` in `apps/cli` compiles `apps/cli/build/songgate`, one file with Bun inside (about 110 MB). The app's address is baked in: `APP_URL` from the environment at build time, else `https://songgate.app`. `--url` picks another, such as `http://localhost:5173` against `bun run dev`. Without building: `bun apps/cli/src/main.ts <command>`.
- `songgate convert <link>` shows the song's links on every service (`found: false` = search only) and the share page, like `/s/…`. `--to apple|youtube|spotify|deezer` asks the converter for matches on one service instead, `--country DE|AT|CH|US|GB` picks the catalogue. `-` reads the link, or a shared text with a link in it, from stdin.
- Output: text for people, with `--json` exactly one JSON value on stdout: the API's answer plus `shareUrl`, errors as `{ "error": "…" }`, the help as a list of commands. Exit codes: 0 done, 1 error (also answers of the API such as `NO_MATCH` or the throttle), 2 wrong usage. Help and messages are in `apps/cli/src/messages.ts` in German and English, the language comes from `LANG` or `--lang`; the API's own errors stay German like the web.
- New commands: a file in `apps/cli/src/commands` like `convert.ts`, entered in `commands` in `src/cli.ts`. A command names help lines, options and `run`, which calls the API through `ctx.api`, reads the answer with zod and returns `{ data, text }`, `data` for `--json`. The tests in `src/cli.test.ts` run the CLI in-process against the real API with faked music services.
- Other platforms: `bun run build --target=bun-darwin-arm64` in `apps/cli` (likewise `bun-linux-x64`, `bun-linux-arm64`, `bun-windows-x64`) overwrites `build/songgate`. The CI builds the file on every run as a check but does not publish it.

## Release builds

Release builds of the app (`mobile.yml`) are built with `--obfuscate`, so stack traces from the app, in GlitchTip too, only show obfuscated names. The symbols are kept for 90 days as the artifacts `symbols-ios` and `symbols-android` of the CI run; the app's build number is that run's number (`gh run list -w mobile.yml --json number,databaseId` gives the run ID). To read a trace:

```sh
gh run download <run-id> -n symbols-android -D /tmp/symbols
flutter symbolize -i trace.txt -d /tmp/symbols/aab/app.android-arm64.symbols   # Play; sideloaded APK: apk/; iOS: app.ios-arm64.symbols
```

Android symbols are separated into `aab/` for Play installations and `apk/` for sideloaded APKs; use the set matching the installation.

`trace.txt` is the raw stack trace with `build_id` and `abs …/virt …` lines (e.g. from `adb logcat`). Builds older than 90 days can no longer be symbolized.

## Abweichungen vom Standard

- Songgate keeps the existing repo `musicstreaming-connector`, iOS bundle IDs `org.musiclink.prototype` / `org.musiclink.prototype.share`, app group, `musiclink://` URL scheme, device storage keys, TestFlight group names and infrastructure identifiers (Coolify, images, tokens). Android uses `org.pleasance.songgate`; share `/s/…` and invite `/f/…` links remain valid.

- The converter throttle in `app.ts` (60 lookups per minute) counts in process memory, not in Postgres: it guards the upstream services' per-IP limits, so a count per instance is right, and the converter runs without a database.
- Signal colours: only the error signal, Songgate has no „your turn“ or „new“ states.
- No README: the sections „Secret scan“, „For agents“, „CLI“ and „Release builds“, which starter keeps in its README, are here.
- The legal pages are not copied into `publicPages` as Markdown: their Markdown has title, description and a link to the HTML page, so there is only one binding version of Impressum and Datenschutz.
- Magic-link verification limits and ALTCHA before login mails do not apply: Songgate has no accounts or login routes and sends only feedback notifications.
- The CLI has no `login`, `whoami`, `logout`, session file or exit code 3: Songgate has no accounts, `convert` needs none. Its tests need no database, they run with plain `bun test`.
- The CLI's texts live in `apps/cli/src/messages.ts`, not in `packages/shared`: there is no shared `messages.ts`, web and API speak German only.
- Biome runs the three rules against `any` via `bun run check`; existing formatting is kept, so this rollout does not enable the starter's other lint/format rules.
