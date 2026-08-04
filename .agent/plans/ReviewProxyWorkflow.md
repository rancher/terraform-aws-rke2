# Plan: Review Proxy Workflow

* **Executed Date:** pending
* **Purpose:** Implement a GitHub Actions workflow that acts as an approval and merge proxy for PR reviewers (like the rancher-dev group) who only have Triage access. When they approve a PR, this workflow will validate their access level, proxy the approval using GITHUB_TOKEN (which has Write access), and enable auto-merge.
* **Goals & Code Snippets:**
  - Create a new workflow file at `.github/workflows/proxy-approve-merge.yml`.
  - Trigger on `pull_request_review` with type `submitted`.
  - Condition job execution on `github.event.review.state == 'approved'`.
  - Validate reviewer association as `MEMBER` or `COLLABORATOR` (ensuring at least Triage access).
  - Use GitHub CLI (`gh`) to proxy approve and enable auto-merge with GITHUB_TOKEN.

---

## Implementation Checklist

### Phase 1: Planning & Setup
- [x] Align with upstream and checkout the `feature/review-proxy-workflow` branch.
- [x] Document the plan in `.agent/plans/ReviewProxyWorkflow.md` (this file).
- [x] Solicit developer approval for this plan.

### Phase 2: Workflow Implementation (Act)
- [x] Create `.github/workflows/proxy-approve-merge.yml` with the specified triggers, permissions, and job conditions.
- [x] Implement Step 1: Validate User (check for `MEMBER` or `COLLABORATOR`).
- [x] Implement Step 2: Checkout Code (using actions/checkout commit SHA).
- [x] Implement Step 3: Proxy Approve & Merge (use `gh pr review --approve` and `gh pr merge --auto --squash` with GITHUB_TOKEN).

### Phase 3: Surgical Verification & Quality Gate
- [x] Run `actionlint` locally to verify workflow syntax correctness.
- [x] Conduct a proactive code review of the modified file diff against `github-copilot-review.instructions.md` to guarantee exactly 0 findings.

### Phase 4: Staging Isolation & IDE Review (Gateway 2)
- [ ] Isolate changes in the active workspace and keep them unstaged.
- [ ] Solicit manual developer IDE review and obtain explicit approval in the chat.

### Phase 5: Authorized Commit, Push & Draft PR (Gateway 3)
- [ ] Stage and commit all changes using the authorized conventional prefix and `APPROVED_BY_USER=1`.
- [ ] Push the branch `feature/review-proxy-workflow` to your origin fork.
- [ ] Generate a Draft Pull Request on GitHub using `.agent/skills/create-pr.sh --draft`.
- [ ] Solicit manual developer review of the draft PR on GitHub and obtain explicit approval to graduate.

### Phase 6: PR Graduation
- [ ] Graduate the draft PR to ready-for-review using `.agent/skills/create-pr.sh --ready`.
