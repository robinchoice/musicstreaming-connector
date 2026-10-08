# MusicLink

## Purpose & links

- Shares songs between YouTube Music, Apple Music, Spotify and Deezer, no sign-up: SvelteKit web (`apps/web`), Hono API (`apps/api`), Flutter app with a share extension (`apps/mobile`).
- Live at https://musiclink.pleasance.org, Coolify on VPS 1, project `pleasance-musiclink`.
- Feedback button in web and app (bug with screenshot, ideas from the footer or the app settings), ported from `robinchoice/starter`. Reports land in Postgres and are mailed to `FEEDBACK_EMAIL`. The tester's email is optional; the Savor workflow „Weihnachtstester“ picks the most helpful testers from it.
- iOS: App Store Connect app `6819013473`, bundle `org.musiclink.prototype`. Signing material and TestFlight groups: `~/dev/New AI Setup/infra.md`.

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
- Postgres holds feedback only. New table: change `packages/db/src/schema.ts`, `bun run --filter @app/db db:generate`; the migration runs on the next API start.
