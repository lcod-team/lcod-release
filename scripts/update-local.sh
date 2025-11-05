#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[update-local] %s\n' "$*" >&2
}

fail() {
  printf '[update-local][error] %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "${ROOT_DIR}/.." && pwd)}"

KERNEL_RS_DIR="${KERNEL_RS_DIR:-${WORKSPACE_ROOT}/lcod-kernel-rs}"
KERNEL_JS_DIR="${KERNEL_JS_DIR:-${WORKSPACE_ROOT}/lcod-kernel-js}"
KERNEL_JAVA_DIR="${KERNEL_JAVA_DIR:-${WORKSPACE_ROOT}/lcod-kernel-java}"
CLI_DIR="${CLI_DIR:-${WORKSPACE_ROOT}/lcod-cli}"

LABEL="${LABEL:-dev-local}"
CLI_SCRIPT="${CLI_DIR}/scripts/lcod"

[[ -d "${KERNEL_RS_DIR}" ]] || fail "Rust kernel directory not found: ${KERNEL_RS_DIR}"
[[ -d "${KERNEL_JS_DIR}" ]] || fail "Node kernel directory not found: ${KERNEL_JS_DIR}"
[[ -d "${KERNEL_JAVA_DIR}" ]] || fail "Java kernel directory not found: ${KERNEL_JAVA_DIR}"
[[ -x "${CLI_SCRIPT}" ]] || fail "CLI helper not found at ${CLI_SCRIPT}"

install_with_cli() {
  local id=$1
  shift
  "${CLI_SCRIPT}" kernel install "${id}" "$@"
}

log "Building Rust kernel (lcod-kernel-rs)"
(
  cd "${KERNEL_RS_DIR}"
  cargo build --release
)
RUST_BIN="${KERNEL_RS_DIR}/target/release/lcod_run"
[[ -x "${RUST_BIN}" ]] || fail "Rust binary not found at ${RUST_BIN}"
install_with_cli rs --path "${RUST_BIN}" --version "${LABEL}" --force

log "Building Node kernel runtime (lcod-kernel-js)"
(
  cd "${KERNEL_JS_DIR}"
  npm install
  npm run bundle:runtime -- --label "${LABEL}"
)
NODE_ARCHIVE="${KERNEL_JS_DIR}/dist/runtime/lcod-runtime-${LABEL}.tar.gz"
[[ -f "${NODE_ARCHIVE}" ]] || fail "Node runtime archive missing: ${NODE_ARCHIVE}"

NODE_STAGE="${KERNEL_JS_DIR}/dist/local-${LABEL}"
rm -rf "${NODE_STAGE}"
mkdir -p "${NODE_STAGE}"
tar -xzf "${NODE_ARCHIVE}" -C "${NODE_STAGE}"
NODE_RUNTIME_ROOT="$(find "${NODE_STAGE}" -maxdepth 2 -type f -name manifest.json -print -quit)"
[[ -n "${NODE_RUNTIME_ROOT}" ]] || fail "Unable to locate manifest inside Node runtime archive"
NODE_RUNTIME_ROOT="$(dirname "${NODE_RUNTIME_ROOT}")"

NODE_WRAPPER="${NODE_STAGE}/lcod-run"
cat > "${NODE_WRAPPER}" <<EOF_WRAPPER
#!/usr/bin/env bash
set -euo pipefail
export LCOD_HOME="${NODE_RUNTIME_ROOT}"
exec node "${KERNEL_JS_DIR}/bin/run-compose.mjs" "\$@"
EOF_WRAPPER
chmod +x "${NODE_WRAPPER}"
install_with_cli node --path "${NODE_WRAPPER}" --version "${LABEL}" --force

log "Building Java kernel (lcod-kernel-java)"
(
  cd "${KERNEL_JAVA_DIR}"
  ./gradlew --quiet build
)
JAVA_JAR="$(ls -1 "${KERNEL_JAVA_DIR}"/build/libs/lcod-run-*.jar 2>/dev/null | head -n1 || true)"
[[ -n "${JAVA_JAR}" ]] || fail "Java kernel jar not found in build/libs"
install_with_cli java --path "${JAVA_JAR}" --version "${LABEL}" --force

log "Rebuilding CLI bundle"
(
  cd "${CLI_DIR}"
  ./scripts/build-bundle.sh
)
CLI_BUNDLE="${CLI_DIR}/dist/lcod"
[[ -x "${CLI_BUNDLE}" ]] || fail "CLI bundle not found at ${CLI_BUNDLE}"

CLI_DEST="${LCOD_CLI_DEST:-}"
if [[ -z "${CLI_DEST}" ]]; then
  if command -v lcod >/dev/null 2>&1; then
    target="$(command -v lcod)"
    if [[ -w "${target}" ]]; then
      CLI_DEST="${target}"
    fi
  fi
fi
if [[ -z "${CLI_DEST}" ]]; then
  CLI_DEST="${HOME}/.local/bin/lcod"
  mkdir -p "$(dirname "${CLI_DEST}")"
fi
cp "${CLI_BUNDLE}" "${CLI_DEST}"
chmod +x "${CLI_DEST}"
log "CLI bundle copied to ${CLI_DEST}"

log "Local environment refreshed with label '${LABEL}'."
log "Rust kernel: ${RUST_BIN}"
log "Node kernel wrapper: ${NODE_WRAPPER}"
log "Java kernel: ${JAVA_JAR}"
