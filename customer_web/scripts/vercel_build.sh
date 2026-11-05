#!/usr/bin/env bash
# Runs from customer_web/, the Vercel project's Root Directory.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
FLUTTER_HOME="/tmp/norve-flutter-${FLUTTER_VERSION}"

# A build without these would only show the "temporarily unavailable" page.
: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel project environment variables}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Vercel project environment variables}"

# Until SUPABASE_AUTH_REDIRECT_URL is set, use Vercel's production address.
AUTH_REDIRECT_URL="${SUPABASE_AUTH_REDIRECT_URL:-}"
if [[ -z "${AUTH_REDIRECT_URL}" && -n "${VERCEL_PROJECT_PRODUCTION_URL:-}" ]]; then
  AUTH_REDIRECT_URL="https://${VERCEL_PROJECT_PRODUCTION_URL}"
fi

"${FLUTTER_HOME}/bin/flutter" build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define="SUPABASE_AUTH_REDIRECT_URL=${AUTH_REDIRECT_URL}"
