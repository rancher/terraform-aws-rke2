# Temporary Plan: Enhance nix-run.sh with Diagnostics and Logs

This temporary plan outlines the step-by-step file-oriented execution for updating `.github/workflows/scripts/nix-run.sh` to provide clear, actionable troubleshooting and diagnostic logging upon failure.

## 1. Create Refactored nix-run.sh

- [x] **Refactor `.github/workflows/scripts/nix-run.sh`**
  - Use structured shell script guidelines (from `.agent/rules/shell-scripts.instructions.md`).
  - Implement custom, colorized logging helpers (`log_info`, `log_success`, `log_warning`, `log_error`).
  - Use shell exit traps to guarantee cleanup of `.nix-script.sh` and log the overall outcome with exit code.
  - Implement robust validation for script preconditions:
    - Verify existence of the `suse` user.
    - Check for `nix` executable at `/home/suse/.nix-profile/bin/nix` or in `PATH`.
    - Detect and log standard CA certificates locations.
  - Add explicit error trapping around the `nix develop` invocation to provide tailored troubleshooting recommendations depending on whether the error happened in Nix setup or in user script execution.

## 2. Verification and Validation

- [x] **Run linting / actionlint on the workflow and shell scripts**
  - Check that the script runs fine with shellcheck/lint checks.
  - Verify that no workflows are broken syntax-wise.
- [x] **Perform dry-run or mock execution check**
  - Verify the script structure and logic locally.
