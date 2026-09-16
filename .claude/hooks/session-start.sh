#!/bin/bash
# Shop Afrik SessionStart hook.
#
# Installs the toolchain so the Flutter app and Cloud Functions can compile and
# the analyzer / tests can run in Claude Code on the web. Idempotent and
# non-interactive — safe to re-run; cached container state makes re-runs cheap.
set -euo pipefail

# Only run in the remote (web) environment; local machines manage their own SDKs.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Run asynchronously: the session starts immediately while tools install in the
# background. The agent may need to wait for this to finish before the first
# analyze/test run on a cold container.
echo '{"async": true, "asyncTimeout": 600000}'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLUTTER_VERSION="3.44.1"
FLUTTER_HOME="${HOME}/flutter"
PUB_CACHE_BIN="${HOME}/.pub-cache/bin"
LOG="$(mktemp)"

log() { echo "[session-start] $*"; }

# --- Flutter SDK (bundled Dart) ---
if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  log "Installing Flutter ${FLUTTER_VERSION}..."
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}"
  curl -fsSL "${URL}" -o "/tmp/${ARCHIVE}" >>"${LOG}" 2>&1
  tar -xf "/tmp/${ARCHIVE}" -C "${HOME}" >>"${LOG}" 2>&1
  rm -f "/tmp/${ARCHIVE}"
else
  log "Flutter already present at ${FLUTTER_HOME}."
fi

export PATH="${FLUTTER_HOME}/bin:${PUB_CACHE_BIN}:${PATH}"
# git treats the SDK dir as "dubious ownership" in some containers.
git config --global --add safe.directory "${FLUTTER_HOME}" >>"${LOG}" 2>&1 || true
flutter config --no-analytics >>"${LOG}" 2>&1 || true

# --- App dependencies ---
log "Fetching Flutter package dependencies..."
( cd "${PROJECT_DIR}" && flutter pub get ) >>"${LOG}" 2>&1

# --- Backend: Cloud Functions + Firebase CLI (emulator / rules tests) ---
if [ -f "${PROJECT_DIR}/functions/package.json" ]; then
  log "Installing Cloud Functions dependencies..."
  ( cd "${PROJECT_DIR}/functions" && npm install ) >>"${LOG}" 2>&1
fi

if ! command -v firebase >/dev/null 2>&1; then
  log "Installing firebase-tools..."
  npm install -g firebase-tools >>"${LOG}" 2>&1
else
  log "firebase-tools already present."
fi

# --- Persist PATH for the session ---
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"${FLUTTER_HOME}/bin:${PUB_CACHE_BIN}:\$PATH\""
  } >> "${CLAUDE_ENV_FILE}"
fi

log "Toolchain ready: $(flutter --version 2>/dev/null | head -1)"
