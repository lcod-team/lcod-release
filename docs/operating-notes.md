# Operating notes

This document captures the initial ideas for the LCOD release orchestrator. It will evolve as automation lands.

## Version manifest

- `VERSION` is the canonical source for semantic versioning across the LCOD stack.
- `scripts/sync-version.sh` updates package manifests in downstream repositories (Node, Rust, etc.).
- Future improvement: generate per-repository changelog snippets based on conventional commits.

### Using `sync-version.sh`

- The script now handles `package.json`, `package-lock.json`, `Cargo.toml`, `Cargo.lock`, and `build.gradle.kts` without requiring optional tooling (`cargo-set-version`, manual npm edits, etc.).
- Example run (from `lcod-release`):
  ```
  ./scripts/sync-version.sh ../lcod-kernel-rs ../lcod-kernel-js ../lcod-kernel-java ../lcod-cli
  ```
- Always run the relevant test suites in each repository after the bump (`cargo test`, `npm test`, `./gradlew test`).

### GitHub workflow `Prepare Release Cascade`

- Manual trigger (`workflow_dispatch`) with an input `version` creates branches `release/v<version>` in `lcod-release` and each downstream repository.
- Requirements:
  - Secret `LCOD_RELEASE_TOKEN` (classic PAT with `repo` scope) to allow pushing branches and opening PRs across organisations.
  - Optional label `release` should exist on target repositories (otherwise GitHub silently ignores the parameter).
- The job publishes a summary with either the PR URL or a note that no changes were needed.
- After the workflow finishes, review/merge the PRs, then proceed with tagging and asset publication.

## Cascade CI

- Spec and resolver changes should trigger kernels to run their full test suites before merging.
- `scripts/trigger-cascade.sh` calls the GitHub API (via `gh workflow run`) to start the appropriate workflows. Override `REPO_LIST` (comma separated) or `WORKFLOW` / `REF` if you need a custom trigger.
- Core test pipelines (`lcod-kernel-rs` rust tests, `lcod-kernel-js` node tests, `lcod-kernel-java` gradle build) now expose a `workflow_dispatch` trigger so the orchestrator (or developers) can re-run them on demand.
- Once stabilised, move the orchestration into a scheduled GitHub Action within this repository.

## Release day checklist (draft)

1. Set the desired version in `VERSION` (e.g. `echo "0.1.15" > VERSION`).
2. Run `./scripts/sync-version.sh …` on every repository that ships artefacts, then commit & push the bumps (reference `lcod-release` issue for traceability).
3. Launch `trigger-cascade.sh` to run the latest CI pipelines on the new version (`REPO_LIST` helps if only a subset needs verification).
4. Tag the kernel releases (`git tag lcod-run-v0.1.15 && git push origin lcod-run-v0.1.15`) and monitor the GitHub Actions release workflow until all artefacts (Linux, macOS arm64/x64, Windows) publish successfully.
5. Update the CLI README/examples if the one-liner mentions a specific version, and regenerate any installer bundles.
6. Kick off the benchmark project and attach the resulting report to the release entry.
