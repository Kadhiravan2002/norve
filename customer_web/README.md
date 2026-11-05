# NORVÉ Customer Web

The customer-facing NORVÉ storefront. Like `admin_web/`, it's a thin Flutter Web package that depends on the root `norve` package and uses the same Supabase backend. It adds no database, backend service or copy of the data.

## Run locally

From this directory, using the git-ignored config file in the repo root:

```
flutter pub get
flutter run -d chrome --web-port 3000 --dart-define-from-file=../supabase.local.json
```

## Test

```
flutter analyze
flutter test
```

## Install as an app

The site is a PWA. In Chrome or Edge on Windows, use the install icon in the address bar. This needs HTTPS, which Vercel provides.

`web/sw.js` handles caching. It saves only the app's own files, and always tries the network first, so a new release arrives straight away. Supabase requests (catalogue, stock, sign-in, checkout and orders) and product images bypass it, so they're never served from its cache. If its caching rules change, update `CACHE_NAME` in that file.

The service worker doesn't run on `localhost`, so `flutter run` isn't affected. Flutter's own `flutter_service_worker.js` removes itself by design and isn't used.

## Deploy on Vercel

Create a separate Vercel project from this repository. Don't change the admin project.

| Setting | Value |
|---|---|
| Root Directory | `customer_web` |
| Include files outside the Root Directory in the Build Step | Enabled (needed for the `norve` path dependency) |
| Framework Preset | Other |
| Install, Build and Output settings | Leave as default; `vercel.json` provides them |

| Environment variable | Value |
|---|---|
| `SUPABASE_URL` | Supabase project URL. Required |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable `sb_publishable_…` key. Required |
| `SUPABASE_AUTH_REDIRECT_URL` | The site's public URL. Defaults to Vercel's production address if unset |

The build stops if a required variable is missing. A build with an invalid value shows a "temporarily unavailable" page rather than any fake products.
