#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
FLUTTER_HOME="/tmp/norve-flutter-${FLUTTER_VERSION}"

: "${SUPABASE_URL:?Set SUPABASE_URL in Vercel project environment variables}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set SUPABASE_PUBLISHABLE_KEY in Vercel project environment variables}"

cd admin_web
"${FLUTTER_HOME}/bin/flutter" build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}" \
  --dart-define="SUPABASE_AUTH_REDIRECT_URL=${SUPABASE_AUTH_REDIRECT_URL:-}"
