# Plan: Simplify Workflows and Commit Validation

* **Executed Date:** pending
* **Purpose:** Simplify repository-wide workflows and commit validation. We consolidate duplicate workflow files, relax the commit message validator to standard Conventional Commits while adding strict file-based gating and character limits (< 70 chars), and add draft pull request graduation support to our create-pr skill.

---

## Goals & Architecture

1. **Workflow Consolidation:** Merge `commit-management.md` into `development-process.md` so that AI agents have a single, unified development workflow.
2. **Standard Quality Gate Integration:** Require that every plan checklist programmatically checkbox-tracks local builds, tests, linters, proactive code reviews, upstream sync, unstaged IDE reviews, authorized commits, and draft PR generation.
3. **Relax Commit Validation:** Support all standard Conventional Commit prefixes (build, chore, ci, docs, feat, feature, fix, perf, refactor, revert, style, test), support optional scopes in parentheses, enforce a strict < 70 character limit on the subject line, and add targeted file-based gating (bumping prefixes are blocked unless root Terraform files are modified).
4. **Draft PR Graduation:** Update `.agent/skills/create-pr.sh` to support the `--ready [target]` option.
5. **Draft PR Graduation Hook Guardrail:** Update `.agent/hooks/block-rancher-git.js` to enforce the `APPROVED_BY_USER=1` prefix requirement for pull request ready / graduation commands.

---

## Implementation Checklist

### Phase 1: Research, Strategy & Planning
- [x] Research existing workflow documentation and locate the `validate-commit-message.sh` and `create-pr.sh` scripts.
- [x] Propose a unified strategy and obtain developer sign-off in the chat.
- [x] Document the plan in `.agent/plans/SimplifyWorkflowsAndCommitValidation.md` (this file).

### Phase 2: Implementation & Code Changes
- [x] Merge `commit-management.md` into `development-process.md` and delete the redundant file.
- [x] Update `plans.instructions.md` and `development-process.md` to mandate the standard quality-gate checklists.
- [x] Relax `validate-commit-message.sh` to allow all Conventional Commits, add file-based gating, and enforce the < 70 character length check.
- [x] Update `create-pr.sh` to add the `--ready` option for graduations.
- [x] Update `.agent/hooks/block-rancher-git.js` to block draft PR graduations unless approved.

### Phase 3: Surgical Verification & Quality Gate
- [x] Run local static analysis and linters (`shellcheck`, `actionlint`, `tflint --recursive`) to verify all scripts and workflows pass.
- [x] Run local Go unit tests in `test/` to verify compiler safety and execution.
- [x] Conduct a proactive code review of the modified file diff against `github-copilot-review.instructions.md` with 0 findings.

### Phase 4: Staging Isolation & IDE Review (Gateway 2)
- [x] Branch off the updated `main` into branch `workflow/simplify-workflows-and-commit-validation`.
- [x] Isolate changes in the active workspace and keep them unstaged.
- [x] Solicit manual developer IDE review and obtain explicit approval in the chat.

### Phase 5: Authorized Commit, Push & PR Graduation (Gateway 3)
- [ ] Stage and commit all changes using the authorized conventional prefix and `APPROVED_BY_USER=1`.
- [ ] Push the branch `workflow/simplify-workflows-and-commit-validation` to your origin fork.
- [ ] Generate a Draft Pull Request on GitHub using `.agent/skills/create-pr.sh --draft`.
- [ ] Graduate the draft PR to ready-for-review using `.agent/skills/create-pr.sh --ready`.
