# NORVÉ Admin Web

Standalone Flutter Web application for NORVÉ administrators. It reuses the root
`norve` package's admin screens, repositories, providers, models and theme.
Administrator membership is verified through Supabase Auth and the existing
`admin_users` table; database RLS policies and authorization RPCs remain the
server-side security boundary.

## Local development

From the repository root:

```powershell
Set-Location admin_web
flutter pub get
flutter run -d chrome --web-port=3001 --dart-define-from-file=../supabase.local.json
```

The configuration file should define `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY`, and optionally `SUPABASE_AUTH_REDIRECT_URL`. Never
put a service-role key or other server secret in this app.

## Production build

From the repository root:

```powershell
Set-Location admin_web
flutter build web --release `
  --dart-define="SUPABASE_URL=$env:SUPABASE_URL" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$env:SUPABASE_PUBLISHABLE_KEY" `
  --dart-define="SUPABASE_AUTH_REDIRECT_URL=$env:SUPABASE_AUTH_REDIRECT_URL"
```

The static site is written to `admin_web/build/web`.

## GitHub and Vercel deployment

1. Push the repository to its existing GitHub repository. The current local
   workspace has no `.git` directory or configured remote, so connect Vercel
   only after opening the correct Git checkout and pushing these files.
2. In Vercel, import that existing GitHub repository and set **Root Directory**
   to the repository root (`.`). The root is required because the standalone
   Flutter package depends on the existing root package by path.
3. Keep the build and install commands from the root `vercel.json`; it installs
   the pinned Flutter SDK 3.47.5 and builds the standalone app to
   `admin_web/build/web`. Vercel rewrites `/admin` paths to the Flutter entry
   document so deep links and refreshes work.
4. Add these Vercel environment variables for Preview and Production:
   - `SUPABASE_URL` — existing project URL.
   - `SUPABASE_PUBLISHABLE_KEY` — the existing `sb_publishable_` key.
   - `SUPABASE_AUTH_REDIRECT_URL` — optional redirect allowed by the existing
     Supabase Auth URL configuration.
5. Deploy and verify sign-in with an authorized administrator and a normal
   customer account. A customer must not enter the dashboard. The UI check is
   additional to, and does not replace, existing RLS/RPC authorization.
6. To let an already-signed-in administrator open the hosted dashboard from
   the customer Android app, include
   `--dart-define=NORVE_ADMIN_WEB_URL=https://<your-vercel-domain>` in that
   customer build. This only provides an external link; it does not move admin
   authorization into the customer app.

The application is not deployed by this repository setup; add no hosted URL
until a Vercel deployment succeeds.
