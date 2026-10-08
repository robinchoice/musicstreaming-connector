# MusicLink

## Purpose & links

- Shares songs between YouTube Music, Apple Music, Spotify and Deezer, no sign-up: SvelteKit web (`apps/web`), Hono API (`apps/api`), Flutter app with a share extension (`apps/mobile`).
- Live at https://musiclink.pleasance.org, Coolify on VPS 1, project `pleasance-musiclink`.
- Feedback button in web and app (bug with screenshot, ideas from the footer or the app settings), ported from `robinchoice/starter`. Reports land in Postgres and are mailed to `FEEDBACK_EMAIL`. The tester's email is optional; the Savor workflow „Weihnachtstester“ picks the most helpful testers from it.
- iOS: App Store Connect app `6819013473`, bundle `org.musiclink.prototype`. Signing material and TestFlight groups: `~/dev/kontor/infra.md`.

## Checks

```sh
cp -n .env.example .env && docker compose up -d   # Postgres on port 5439 for the API tests
bun install --frozen-lockfile && bun run check && bun run test && bun run build
cd apps/mobile && flutter pub get && flutter analyze && flutter test   # when apps/mobile changed
```

## Deploy

- A push to `main` runs `ci.yml`: checks, builds the images, then deploys them through the Coolify API.
- Pushes that touch `apps/mobile` also run `mobile.yml`, which uploads an iOS build to TestFlight and builds the Android bundle.
- Verify: `gh run watch`, then `curl -s https://musiclink.pleasance.org/api/health`.

## Pitfalls

- The bundle ID `org.musiclink.prototype` and the repo name predate the naming rules and stay as they are.
- The iOS app signs with explicit distribution profiles for the app and the share extension (secrets `IOS_CERTIFICATE_BASE64`, `IOS_APP_PROFILE_BASE64`, `IOS_SHARE_PROFILE_BASE64`). A new extension or capability needs new profiles.
- No GitHub issues for feedback: the repo is public, reports and screenshots would be too. They stay in the database and the mail.
- adapter-node accepts 512 KB request bodies by default. `Dockerfile.web` raises `BODY_SIZE_LIMIT`, otherwise app screenshots (PNG) fail with 413 at the web proxy.
- Share links (`/s/yt/<id>`, `/s/am/<country>/<id>`, `/s/sp/<id>`, `/s/dz/<id>`) and invite links (`/f/<service>?name=…`) carry everything they need and are out in chats. Keep both formats readable; `sharePath` in the API and `sourceLink` in the web share page must match.
- Friends and groups live only on the device: web in localStorage, app as one JSON string via the preferences channel (`getSocial`/`setSocial`), on iOS in the app group so the share extension reads the same list. The invite page opens the app with `musiclink://app/friend?name=…&service=…`, a plain URL scheme that needs no new signing profile. The API caches `/api/v1/song` results in memory for 24 hours; the privacy page says so.
- Link previews: the layout sets the `og:` tags, public pages override title, description and an absolute image (song covers) with `meta` from their load (`/s/…` server load, `/f/[service]` `+page.ts`). Crawlers run no JavaScript, so `meta` only works on SSR pages. The web is German only, so there is one picture, `static/og-image-de.png`: rerun `bun run og-image` in `apps/web` and commit it when `APP_NAME`, `APP_BAND`, `APP_TAGLINE` or the tile `static/favicon.svg` (same as `img/werkzeuge/musiclink.svg` in the pleasance repo) change. WhatsApp caches previews for a long time.
- Postgres holds feedback only. New table: change `packages/db/src/schema.ts`, `bun run --filter @app/db db:generate`; the migration runs on the next API start.
