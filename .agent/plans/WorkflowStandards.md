# Workflow Standards

**Executed Date:** pending
**Purpose:** Update all workflows to have a standard step structure, extract all scripts so they can be linted, use commit hashes for action versioning, implement least privilege security principle, and consolidate workflow/linter scripts to eliminate redundant overhead and files.

---

- All jobs must define explicit `permissions:`. All workflows should have `permissions: {}` at the top level. Set scopes to `none` as needed. Permissions should implement least privilege necessary access.
- Pin all actions (including `actions/*`, `github/*`, `rancher/*`) to a full 40-character commit SHA, not a tag. The `uses:` line MUST include the version (e.g., `# v6.0.2`). On the line before the `uses:` there should be a comment with a link to the releases page for the action (e.g. `# https://github.com/actions/github-script/releases`).
- Only pre-approved action namespaces are allowed. Approved namespaces are documented at: https://github.com/rancher/security-team/blob/main/docs/standards/rancher-gha-standards.md#allowed-github-actions. Important ones include: `https://github.com/actions/*`, `https://github.com/aquasecurity/*`, `https://github.com/aws-actions/*`, `https://github.com/dependabot/*`, `https://github.com/fossas/fossa-action@*`, `https://github.com/golang/*`, `https://github.com/golangci/*`, `https://github.com/google-github-actions/*`, `https://github.com/google/*`, `https://github.com/googleapis/release-please-action@*`, `https://github.com/goreleaser/*`, `https://github.com/hashicorp/setup-terraform@*`, `https://github.com/hashicorp/vault-action@*`, `https://github.com/rancher-eio/*`, `https://github.com/renovatebot/*`, and `https://github.com/updatecli/*`.
- Never inline untrusted context variables in `run` scripts. Use environment variables (e.g., `env: VAR: ${{...}}`).
- Remove and replace any `pull_request_target` triggered workflows, this trigger is banned.
- Every `job` must have an explicit `timeout-minutes`. Don't use the 360-minute default.
- Use `concurrency` blocks in PR workflows to cancel redundant runs (e.g., `group: ${{ github.workflow }}-${{ github.ref }}`).
- Suggest `actions/cache` or action-specific caching to speed up dependency downloads.
- Workflows should orchestrate, not execute. They may call out to external actions or internal scripts, but must not execute full steps by themselves. Replace any step which executes without calling out to an external action or internal script.
- All `run` or `github-script` scripts should be placed in the `.github/workflows/scripts` directory. Do not use inline JavaScript in `actions/github-script`.
- All scripts should be validated in the `pull_request.yaml` workflow. If any aren't validated, add them.
- All workflows, jobs, and steps need a descriptive `name`.
  - workflow steps should have the following format:
    ```
    - name: Step Name
      id: step-name
      # http://github.com/owner/repo/releases
      uses: owner/repo
      ...
    ```
    OR
    ```
    - name: Step Name
      id: step-name
      run: ${{ github.workspace }}/.github/workflows/scripts/script-name.sh
      ...
    ```
  Update any workflow steps necessary to meet this guideline.

## CI Script Consolidation and Simplification

To reduce GitHub Actions runner overhead, improve execution speed, and maintain a cleaner codebase, we will:
- **Consolidate Linters:** Combine `lint-terraform.sh`, `eslint.sh`, `actionlint.sh`, `shellcheck.sh`, and `gitleaks.sh` into a single, unified `lint-all.sh` static analysis script. This allows us to run a single, high-performance static analysis job in `pull_request.yaml` instead of 5 separate container spin-ups.
- **Eliminate Unused/Redundant Scripts:**
  - Remove `.github/workflows/scripts/commit-go-deps-changes.sh` (unused, replaced by `create-verified-pr.js`).
  - Remove `.github/workflows/scripts/create-pr.js` (unused, replaced by `create-verified-pr.js`).
  - Remove `.github/workflows/scripts/execute-tests.sh` (redundant wrapper; call `run_tests.sh -s` directly instead).
- **Consolidate Comments:** Combine `.github/workflows/scripts/pr-e2e-wait.js` and `.github/workflows/scripts/pr-e2e-pass.js` into a single versatile `.github/workflows/scripts/comment-pr.js` script that accepts an action type/status (e.g. `'wait'` or `'pass'`) as an environment variable or argument.
