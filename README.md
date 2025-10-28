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

## Next steps

- Finalise the version propagation script so kernels and resolver stay aligned.
- Draft GitHub Actions workflows that call the cascade helpers.
- Integrate benchmark orchestration once the baseline suite is ready.

Contributions and RFCs should be documented in `docs/` before automation is merged.
