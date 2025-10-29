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

if [[ -n "${LCOD_VERSION:-}" ]]; then
  VERSION="${LCOD_VERSION}"
else
  VERSION="$(<"${VERSION_FILE}")"
fi

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

    if [[ -f "${repo}/package-lock.json" ]]; then
      echo " - Updating package-lock.json in ${repo}"
      PACKAGE_LOCK="${repo}/package-lock.json" TARGET_VERSION="${VERSION}" node <<'NODE'
const fs = require('fs');
const path = process.env.PACKAGE_LOCK;
const version = process.env.TARGET_VERSION;
const raw = fs.readFileSync(path, 'utf8');
const data = JSON.parse(raw);
data.version = version;
if (data.packages && data.packages['']) {
  data.packages[''].version = version;
}
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
NODE
    fi
  fi

  package_name=""

  if [[ -f "${repo}/Cargo.toml" ]]; then
    package_name="$(CARGO_MANIFEST="${repo}/Cargo.toml" python3 <<'PY'
import os
import pathlib

manifest_path = pathlib.Path(os.environ["CARGO_MANIFEST"])
text = manifest_path.read_text().splitlines()
in_package = False
name = None

for line in text:
    stripped = line.strip()
    if stripped.startswith("["):
        if stripped == "[package]":
            in_package = True
            continue
        elif in_package:
            break
    if in_package and stripped.startswith("name"):
        parts = line.split("=", 1)
        if len(parts) == 2:
            value = parts[1].strip().strip('"')
            if value:
                name = value
        break

if name:
    print(name)
PY
)" || package_name=""

    echo " - Updating Cargo.toml in ${repo}"
    if cargo --list 2>/dev/null | grep -q 'set-version'; then
      cargo set-version "${VERSION}" --manifest-path "${repo}/Cargo.toml"
    else
      CARGO_MANIFEST="${repo}/Cargo.toml" TARGET_VERSION="${VERSION}" python3 <<'PY'
import os
import pathlib
import sys

manifest_path = pathlib.Path(os.environ["CARGO_MANIFEST"])
version = os.environ["TARGET_VERSION"]
text = manifest_path.read_text()
lines = text.splitlines()
in_package = False
updated = False

for idx, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("["):
        if stripped == "[package]":
            in_package = True
            continue
        elif in_package:
            break
    if in_package and stripped.startswith("version"):
        parts = line.split("=", 1)
        if len(parts) == 2:
            prefix = parts[0].rstrip()
            lines[idx] = f'{prefix} = "{version}"'
            updated = True
            break

if not updated:
    print("Warning: version field not found in Cargo.toml", file=sys.stderr)
else:
    trailing_newline = text.endswith("\n")
    manifest_path.write_text("\n".join(lines) + ("\n" if trailing_newline else ""))
PY
    fi

    if [[ -f "${repo}/Cargo.lock" && -n "${package_name}" ]]; then
      echo " - Updating Cargo.lock in ${repo}"
      CARGO_LOCK="${repo}/Cargo.lock" PACKAGE_NAME="${package_name}" TARGET_VERSION="${VERSION}" python3 <<'PY'
import os
import pathlib
import sys

lock_path = pathlib.Path(os.environ["CARGO_LOCK"])
target_name = os.environ["PACKAGE_NAME"]
version = os.environ["TARGET_VERSION"]
original_text = lock_path.read_text()
lines = original_text.splitlines()
updated = False

for idx, line in enumerate(lines):
    if line.strip() == f'name = "{target_name}"':
        j = idx + 1
        while j < len(lines):
            stripped = lines[j].strip()
            if stripped.startswith("version"):
                parts = lines[j].split("=", 1)
                if len(parts) == 2:
                    prefix = parts[0].rstrip()
                    lines[j] = f'{prefix} = "{version}"'
                    updated = True
                break
            if stripped.startswith("name") and stripped != f'name = "{target_name}"':
                break
            j += 1
        break

if updated:
    lock_path.write_text("\n".join(lines) + ("\n" if original_text.endswith("\n") else ""))
else:
    print(f"Warning: unable to update Cargo.lock version for {target_name}", file=sys.stderr)
PY
    fi
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
