# Temporary Plan: CI/CD Workflows and Scripts Consolidation

This temporary plan outlines the step-by-step file-oriented execution for auditing, consolidating, and cleaning up the repository's workflow scripts and GitHub Actions.

## 1. Create Consolidated Scripts

- [x] **Create `.github/workflows/scripts/lint-all.sh`**
  - Consolidates:
    - `lint-terraform.sh` (`terraform fmt` & `tflint`)
    - `eslint.sh` (`eslint .`)
    - `actionlint.sh` (`actionlint`)
    - `shellcheck.sh` (`shellcheck` on all shebang-enabled files)
    - `gitleaks.sh` (`gitleaks detect`)
  - Ensures robust execution by running all static analysis steps and collecting a cumulative exit code.
- [x] **Create `.github/workflows/scripts/comment-pr.js`**
  - Consolidates:
    - `pr-e2e-wait.js` (commenting that e2e tests are running)
    - `pr-e2e-pass.js` (commenting that e2e tests have passed)
  - Leverages process environment variable `COMMENT_STATUS` (`wait` / `pass`) to dictate the comment body dynamically.

## 2. Modify Workflows

- [x] **Modify `.github/workflows/pull_request.yaml`**
  - Consolidate individual static linter jobs (`terraform`, `eslint`, `actionlint`, `shellcheck`, `gitleaks`) into a single unified `static-analysis` job.
  - Update `static-analysis` job to run the new `.github/workflows/scripts/lint-all.sh` script via `nix-run.sh`.
  - Keep specialized pull request checks (`validate-commit-message` and `signed-commits`) intact as they are specifically bound to GitHub API/events.
- [x] **Modify `.github/workflows/test.yaml`**
  - Eliminate the redundant `execute-tests.sh` wrapper.
  - Run `bash ./run_tests.sh -s` directly via `nix-run.sh`.
- [x] **Modify `.github/workflows/release.yaml`**
  - Eliminate the redundant `execute-tests.sh` wrapper.
  - Run `bash ./run_tests.sh -s` directly via `nix-run.sh`.
  - Update comment steps to use the consolidated `.github/workflows/scripts/comment-pr.js` script with `COMMENT_STATUS` environment variables (`wait` and `pass`).

## 3. Delete Obsolete and Consolidated Files

- [x] **Remove obsolete static analysis scripts:**
  - `.github/workflows/scripts/lint-terraform.sh`
  - `.github/workflows/scripts/eslint.sh`
  - `.github/workflows/scripts/actionlint.sh`
  - `.github/workflows/scripts/shellcheck.sh`
  - `.github/workflows/scripts/gitleaks.sh`
- [x] **Remove unused automation/dependency scripts:**
  - `.github/workflows/scripts/commit-go-deps-changes.sh` (Obsolete; replaced by verified PR API/creation)
  - `.github/workflows/scripts/create-pr.js` (Obsolete; replaced by `create-verified-pr.js`)
- [x] **Remove redundant and consolidated orchestration scripts:**
  - `.github/workflows/scripts/execute-tests.sh` (Obsolete; `run_tests.sh` called directly)
  - `.github/workflows/scripts/pr-e2e-wait.js` (Consolidated into `comment-pr.js`)
  - `.github/workflows/scripts/pr-e2e-pass.js` (Consolidated into `comment-pr.js`)

## 4. Verification and Validation

- [x] **Run Linter / Static Analysis on the entire repository**
  - Verify that the consolidated `lint-all.sh` runs successfully inside a local environment.
  - Fix any formatting or lint issues identified by the consolidated static analysis run.
- [x] **Verify workflow syntax**
  - Ensure all updated workflow YAMLs (`pull_request.yaml`, `test.yaml`, `release.yaml`) pass `actionlint`.
