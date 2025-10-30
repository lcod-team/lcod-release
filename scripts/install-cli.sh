#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[install] %s\n' "$*"
}

fail() {
  printf '[install] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Command '$1' is required. Please install it and retry."
  fi
}

python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3'
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf 'python'
    return 0
  fi
  return 1
}

MANIFEST_URL=${LCOD_RELEASE_MANIFEST_URL:-https://github.com/lcod-team/lcod-release/releases/latest/download/release-manifest.json}
CLI_ARCHIVE_URL=${LCOD_CLI_ARCHIVE_URL:-}

require_cmd curl
require_cmd tar

TMP_ROOT=$(mktemp -d)
cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

MANIFEST_PATH="${TMP_ROOT}/manifest.json"
ARCHIVE_PATH="${TMP_ROOT}/lcod-cli.tar.gz"
EXTRACT_ROOT="${TMP_ROOT}/cli"

mkdir -p "${EXTRACT_ROOT}"

if [[ -z "${CLI_ARCHIVE_URL}" ]]; then
  PYTHON_BIN=$(python_cmd) || fail "Python 3 is required to parse the release manifest."
  log "Fetching release manifest"
  curl -fsSL "${MANIFEST_URL}" -o "${MANIFEST_PATH}" || fail "Unable to download manifest from ${MANIFEST_URL}"
  CLI_ARCHIVE_URL=$("${PYTHON_BIN}" - <<'PY' "${MANIFEST_PATH}"
import json, sys
manifest_path = sys.argv[1]
with open(manifest_path, 'r', encoding='utf-8') as fh:
    manifest = json.load(fh)
assets = manifest.get('cli', {}).get('assets', [])
for asset in assets:
    name = asset.get('name', '')
    url = asset.get('download_url')
    if name.endswith('.tar.gz') and url:
        print(url)
        break
else:
    raise SystemExit("No CLI tarball (.tar.gz) found in release manifest")
PY
) || fail "Unable to determine CLI archive download URL from manifest"
fi

log "Downloading CLI bundle"
curl -fL "${CLI_ARCHIVE_URL}" -o "${ARCHIVE_PATH}" || fail "Failed to download CLI archive from ${CLI_ARCHIVE_URL}"

log "Unpacking CLI bundle"
tar -xzf "${ARCHIVE_PATH}" -C "${EXTRACT_ROOT}" || fail "Failed to extract CLI archive"

INSTALL_SCRIPT="${EXTRACT_ROOT}/install.sh"
if [[ ! -f "${INSTALL_SCRIPT}" ]]; then
  fail "CLI archive does not contain install.sh"
fi

log "Installing lcod CLI"
SOURCE_DIR="${EXTRACT_ROOT}" bash "${INSTALL_SCRIPT}" "$@" || fail "Installation script reported an error"

log "Installation completed successfully."
