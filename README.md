# lcod-release

Orchestration tooling for the LCOD ecosystem. This repository sets the release cadence, versioning strategy, and cross-repository automation for:

- `lcod-spec`
- `lcod-resolver`
- Kernel implementations (`lcod-kernel-js`, `lcod-kernel-rs`, `lcod-kernel-java`, …)
- Downstream tooling such as `lcod-cli`

## Goals

1. **Single source of truth for versions**  
   Maintain a canonical `VERSION` manifest and helper scripts that propagate the number into each repository before tagging.

2. **Cascade CI triggers**  
   Whenever shared specification code changes, automatically run the kernel matrices to catch regressions early.

3. **Unified release flow**  
   Provide scripts/workflows that publish artifacts (binaries, runtime bundles, changelog) across all runtimes in one go.

4. **Benchmarks & reporting**  
   After a release, execute benchmark suites across kernels and attach the generated reports to the release.

## Repository layout

```
VERSION                # Canonical semantic version (e.g. 0.1.12)
scripts/               # Shell utilities (sync versions, trigger cascade CI, publish release notes)
docs/                  # Design notes and operating procedures
```

The repository is intentionally light; each script should be usable locally and in CI environments.

## Getting started

```
git clone git@github.com:lcod-dev/lcod-release.git
cd lcod-release
```

The scripts require Bash ≥ 4, `curl`, `jq`, and the GitHub CLI (`gh`). Use `./scripts/bootstrap.sh` to check prerequisites once it lands.

## Install the LCOD CLI in one command

The aggregated releases published from this repository expose a turn-key installer. To install the latest tagged CLI binary:

```bash
curl -fsSL https://github.com/lcod-team/lcod-release/releases/latest/download/install.sh | bash
```

The script downloads the CLI bundle from the release manifest, reuses the official installer from `lcod-cli`, and places the `lcod` executable into a writable directory (`~/.lcod/bin`, `~/.local/bin`, …). On Windows/PowerShell, the equivalent command is:

```powershell
irm https://github.com/lcod-team/lcod-release/releases/latest/download/install.ps1 | iex
```

Both scripts accept the same options as the original installer (`LCOD_INSTALL_DIR`, `LCOD_INSTALL_NAME`, …). They also work offline when `LCOD_CLI_ARCHIVE_URL` is set to a locally cached tarball (for Bash) or zip (for PowerShell).

## Refresh a local pre-release workspace

When you need to smoke-test a build across every kernel before tagging, run the helper from the release repo:

```bash
./scripts/update-local.sh
```

It performs the following steps:

1. Builds `lcod-kernel-rs` in release mode and installs it into the CLI manifest as `rs@dev-local`.
2. Bundles `lcod-kernel-js`, extracts the runtime, and installs a wrapper pointing to the freshly built compose runner.
3. Rebuilds the Java kernel and installs the jar into the manifest.
4. Regenerates the CLI bundle and copies it to your `lcod` executable (defaults to `~/.local/bin/lcod` if the existing binary is not writable).

Override repository locations or labels via environment variables:

```bash
WORKSPACE_ROOT=~/git LABEL=dev-$(date +%Y%m%d%H%M) ./scripts/update-local.sh
```

You can also override specific paths with `KERNEL_RS_DIR`, `KERNEL_JS_DIR`, `KERNEL_JAVA_DIR`, `CLI_DIR`, or force the CLI install destination via `LCOD_CLI_DEST`.

## Next steps

- Finalise the version propagation script so kernels and resolver stay aligned.
- Draft GitHub Actions workflows that call the cascade helpers.
- Integrate benchmark orchestration once the baseline suite is ready.

Contributions and RFCs should be documented in `docs/` before automation is merged.
