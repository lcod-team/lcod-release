# Operating notes

This document captures the initial ideas for the LCOD release orchestrator. It will evolve as automation lands.

## Version manifest

- `VERSION` is the canonical source for semantic versioning across the LCOD stack.
- `scripts/sync-version.sh` updates package manifests in downstream repositories (Node, Rust, etc.).
- Future improvement: generate per-repository changelog snippets based on conventional commits.

## Cascade CI

- Spec and resolver changes should trigger kernels to run their full test suites before merging.
- `scripts/trigger-cascade.sh` calls the GitHub API (via `gh workflow run`) to start the appropriate workflows.
- Once stabilised, move the orchestration into a scheduled GitHub Action within this repository.

## Release day checklist (draft)

1. Run cascade CI on the candidate commit (`trigger-cascade.sh`).
2. Sync the version across repositories and open PRs with the bump.
3. Generate release notes and publish runtime bundles (`lcod-run`, NPM packages, etc.).
4. Kick off the benchmark project and attach the resulting report to the release entry.
