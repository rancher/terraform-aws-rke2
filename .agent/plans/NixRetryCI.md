# Plan: Nix Environment Startup Retry Logic

**Executed Date:** 2026-08-12
**Purpose:** Implement automated retry logic inside `.github/workflows/scripts/nix-run.sh` to handle transient network errors (such as HTTP 503) when fetching flake dependencies (e.g. `flake-utils`) during Nix environment initialization.
**Goals & Code Snippets:**
We will wrap the `nix develop` initialization call in a retry loop (up to 5 attempts with incremental backoff).
To prevent retrying failed commands (like failing tests), we will use a canary file `.nix-entered` created at the very start of command execution inside the Nix shell:
- If `nix develop` fails but `.nix-entered` exists, it means environment initialization succeeded but the user command failed, so we DO NOT retry.
- If `nix develop` fails and `.nix-entered` does NOT exist, it means the failure occurred during environment download/setup, so we WILL retry.
- We will also analyze the pre-existing environment and safely log (names only, no values) any environment variables that were suppressed/excluded when entering the Nix shell.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/NixRetryCI.md`.
- [x] Implement suppressed environment variable detection and logging (names only) in `.nix-script.sh` generation inside `.github/workflows/scripts/nix-run.sh`.
- [x] Implement `.nix-entered` creation in `.nix-script.sh` generation inside `.github/workflows/scripts/nix-run.sh`.
- [x] Add the retry loop with backoff and canary detection in `run_nix_command()` of `.github/workflows/scripts/nix-run.sh`.
- [x] Clean up `.nix-entered` in `cleanup()` of `.github/workflows/scripts/nix-run.sh`.
- [x] Static Validation: Run `shellcheck .github/workflows/scripts/nix-run.sh`.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Ensure branch and changes are isolated.
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [x] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
