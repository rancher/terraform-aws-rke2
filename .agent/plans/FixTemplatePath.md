# Plan: Fix Template Path for Examples

**Executed Date:** 2026-08-12
**Purpose:** Resolve the failing release CI jobs (`layout`, `suse`, `ipfamily`) caused by an invalid `template_path` parameter in `examples/ha`, `examples/prod`, and `examples/splitrole`.
**Goals & Code Snippets:** 
We will update `main.tf` in the `ha`, `prod`, and `splitrole` examples to correctly set `template_path = abspath("${path.module}/config_files")`.
We will also correct a stale comment in `examples/splitrole/main.tf` referencing `./templates`.

## Implementation Checklist
- [x] Write this approved plan to the workspace at `.agent/plans/FixTemplatePath.md`.
- [x] Update `template_path` to `config_files` in `examples/ha/main.tf`.
- [x] Update `template_path` to `config_files` in `examples/prod/main.tf`.
- [x] Update `template_path` to `config_files` and fix the comment in `examples/splitrole/main.tf`.
- [x] Implementation Verification: Run `tflint --recursive` and execute a fast verification test locally (e.g., `./run_tests.sh -f sles-16-canal-stable-ha-rpm-ipv4 &> /tmp/run_tests.log`).
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Execute `git-sync.sh`, branch off, and present the unstaged diff for IDE Review.
- [x] Developer IDE Review Gateway: Wait for explicit manual approval, then commit and push using `APPROVED_BY_USER=1`.
- [x] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.