#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.5}"
FLUTTER_HOME="/tmp/norve-flutter-${FLUTTER_VERSION}"
FLUTTER_ARCHIVE="/tmp/norve-flutter-${FLUTTER_VERSION}.tar.xz"

if [[ ! -x "${FLUTTER_HOME}/bin/flutter" ]]; then
  mkdir -p "${FLUTTER_HOME}"
  curl --fail --location --silent --show-error \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    --output "${FLUTTER_ARCHIVE}"
  tar -xJf "${FLUTTER_ARCHIVE}" -C "${FLUTTER_HOME}" --strip-components=1
  rm -f "${FLUTTER_ARCHIVE}"
fi

"${FLUTTER_HOME}/bin/flutter" --version
cd admin_web
"${FLUTTER_HOME}/bin/flutter" pub get
