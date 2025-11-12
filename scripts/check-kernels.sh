#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fatal() {
  echo "error: $*" >&2
  exit 1
}

resolve_or_die() {
  local label="$1"
  local path="$2"
  if [ ! -d "$path" ]; then
    fatal "cannot find $label at $path (override via env var)"
  fi
  (cd "$path" >/dev/null 2>&1 && pwd)
}

default_repo_path() {
  local name="$1"
  local candidate="$ROOT_DIR/../$name"
  if [ -d "$candidate" ]; then
    (cd "$candidate" >/dev/null 2>&1 && pwd)
  else
    echo ""
  fi
}

ensure_npm_dependencies() {
  local dir="$1"
  if [ -d "$dir/node_modules" ]; then
    return
  fi
  log "Installing npm dependencies in $dir"
  (cd "$dir" && npm install >/dev/null)
}

SPEC_DIR="${SPEC_REPO_PATH:-$(default_repo_path lcod-spec)}"
RESOLVER_DIR="${LCOD_RESOLVER_PATH:-$(default_repo_path lcod-resolver)}"
COMPONENTS_DIR="${LCOD_COMPONENTS_PATH:-$(default_repo_path lcod-components)}"
KERNEL_RS_DIR="${KERNEL_RS_DIR:-$(default_repo_path lcod-kernel-rs)}"
KERNEL_JS_DIR="${KERNEL_JS_DIR:-$(default_repo_path lcod-kernel-js)}"
KERNEL_JAVA_DIR="${KERNEL_JAVA_DIR:-$(default_repo_path lcod-kernel-java)}"

SPEC_DIR="$(resolve_or_die SPEC_REPO_PATH "$SPEC_DIR")"
RESOLVER_DIR="$(resolve_or_die LCOD_RESOLVER_PATH "$RESOLVER_DIR")"
COMPONENTS_DIR="$(resolve_or_die LCOD_COMPONENTS_PATH "$COMPONENTS_DIR")"
KERNEL_RS_DIR="$(resolve_or_die KERNEL_RS_DIR "$KERNEL_RS_DIR")"
KERNEL_JS_DIR="$(resolve_or_die KERNEL_JS_DIR "$KERNEL_JS_DIR")"
KERNEL_JAVA_DIR="$(resolve_or_die KERNEL_JAVA_DIR "$KERNEL_JAVA_DIR")"

if [ "${SKIP_UPDATE_LOCAL:-0}" != "1" ]; then
  log "Running update-local to refresh kernels"
  "$ROOT_DIR/scripts/update-local.sh"
else
  log "Skipping update-local (SKIP_UPDATE_LOCAL=1)"
fi

run_rust_suite() {
  log "Rust kernel: cargo test"
  pushd "$KERNEL_RS_DIR" >/dev/null
  SPEC_REPO_PATH="$SPEC_DIR" \
  LCOD_RESOLVER_PATH="$RESOLVER_DIR" \
  LCOD_RESOLVER_COMPONENTS_PATH="$RESOLVER_DIR/packages/resolver/components" \
  cargo test

  log "Rust kernel: spec fixtures (test_specs)"
  SPEC_REPO_PATH="$SPEC_DIR" cargo run --bin test_specs
  popd >/dev/null
}

run_node_suite() {
  log "Node kernel: ensuring npm dependencies"
  ensure_npm_dependencies "$KERNEL_JS_DIR"
  ensure_npm_dependencies "$SPEC_DIR"

  log "Node kernel: npm test"
  pushd "$KERNEL_JS_DIR" >/dev/null
  SPEC_REPO_PATH="$SPEC_DIR" \
  LCOD_RESOLVER_PATH="$RESOLVER_DIR" \
  LCOD_RESOLVER_COMPONENTS_PATH="$RESOLVER_DIR/packages/resolver/components" \
  LCOD_COMPONENTS_PATH="$COMPONENTS_DIR" \
  npm test

  log "Node kernel: spec fixtures (npm run test:spec)"
  SPEC_REPO_PATH="$SPEC_DIR" \
  LCOD_COMPONENTS_PATH="$COMPONENTS_DIR" \
  npm run test:spec
  popd >/dev/null
}

run_java_suite() {
  log "Java kernel: ensuring spec dependencies"
  ensure_npm_dependencies "$SPEC_DIR"

  log "Java kernel: ./gradlew check lcodRunJar lcodRunnerLib"
  pushd "$KERNEL_JAVA_DIR" >/dev/null
  SPEC_REPO_PATH="$SPEC_DIR" \
  RESOLVER_REPO_PATH="$RESOLVER_DIR" \
  ./gradlew check lcodRunJar lcodRunnerLib

  log "Java kernel: spec fixtures (./gradlew specTests)"
  SPEC_REPO_PATH="$SPEC_DIR" \
  RESOLVER_REPO_PATH="$RESOLVER_DIR" \
  ./gradlew specTests
  popd >/dev/null
}

run_rust_suite
run_node_suite
run_java_suite

log "Kernel test matrix completed successfully"
