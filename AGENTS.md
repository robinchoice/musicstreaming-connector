# MusicLink

## Purpose & links

- Shares songs between YouTube Music and Apple Music, no sign-up: SvelteKit web (`apps/web`), Hono API (`apps/api`), Flutter app with a share extension (`apps/mobile`).
- Live at https://musiclink.pleasance.org, Coolify on VPS 1, project `pleasance-musiclink`.
- iOS: App Store Connect app `6819013473`, bundle `org.musiclink.prototype`. Signing material and TestFlight groups: `~/dev/New AI Setup/infra.md`.

## Checks

```sh
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
