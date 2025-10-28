#!/usr/bin/env bash
set -euo pipefail

# Synchronise the version declared in VERSION into downstream repositories.
# Expected usage:
#   ./scripts/sync-version.sh /path/to/lcod-spec /path/to/lcod-resolver ...

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "VERSION file not found at ${VERSION_FILE}" >&2
  exit 1
fi

VERSION="$(<"${VERSION_FILE}")"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <repo-path> [<repo-path> ...]" >&2
  exit 1
fi

echo "Syncing LCOD version ${VERSION}"

for repo in "$@"; do
  if [[ ! -d "${repo}" ]]; then
    echo "Skipping ${repo}: not a directory" >&2
    continue
  fi

  if [[ -f "${repo}/package.json" ]]; then
    echo " - Updating package.json in ${repo}"
    npx --yes json -I -f "${repo}/package.json" -e "this.version='${VERSION}'"
  fi

  if [[ -f "${repo}/Cargo.toml" ]]; then
    echo " - Updating Cargo.toml in ${repo}"
    cargo set-version "${VERSION}" --manifest-path "${repo}/Cargo.toml"
  fi

  if [[ -f "${repo}/build.gradle.kts" ]]; then
    echo " - Updating build.gradle.kts in ${repo}"
    tmp_file="$(mktemp)"
    awk -v ver="${VERSION}" '
      BEGIN { updated=0 }
      /^[[:space:]]*version[[:space:]]*=/ {
        sub(/"[^"]*"/, "\"" ver "\"")
        updated=1
      }
      { print }
      END {
        if (updated == 0) {
          printf "Warning: version declaration not found in build.gradle.kts\n" > "/dev/stderr"
        }
      }
    ' "${repo}/build.gradle.kts" > "${tmp_file}"
    mv "${tmp_file}" "${repo}/build.gradle.kts"
  fi
done

echo "Done."
