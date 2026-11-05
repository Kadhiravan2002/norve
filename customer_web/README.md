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
