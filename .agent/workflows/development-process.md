# Workflow: Standard Development Process

This is the standard development process. All AI agents MUST strictly read, understand, and follow this unified process for any session, feature implementation, refactoring, maintenance, or bug fix.

---

## Core Mandates

1. **Zero Data Loss Guarantee:** Never run destructive git commands (such as `git reset --hard`, `git checkout .`, or `git clean -fd`) on modified workspace files unless explicitly requested by the developer, or after backing up work to a temporary branch/stash or the standard backup folder.
2. **IDE Review Priority:** The developer prefers to review code changes directly in their IDE while they are **unstaged** in the Git working directory to maintain color-coded diff visibility. Never execute a `git commit` without presenting the exact unstaged diff and receiving explicit approval in the chat.
3. **No Upstream Pushes:** Never push directly to upstream "rancher" remotes. All remote operations must target the user's fork.
4. **Strict Release-Please & SemVer Rules (Product-Centric):** All draft commit messages must strictly adhere to Release-Please rules from the end-user product's perspective:
   - **`feat`** (bumping SemVer Minor) and **`refactor`/`!`** (bumping SemVer Major) MUST ONLY be used if the change directly modifies the Terraform files defining the published module itself (`main.tf`, `variables.tf`, `versions.tf`, or `outputs.tf`).
   - **Internal Dev Changes:** Changes to helper scripts, CI/CD configuration, linters, internal hooks, or test suites DO NOT affect the published product. They MUST NOT use `feat`, `refactor`, or `!` types. Instead, use non-bumping conventional prefixes such as `build`, `ci`, `test`, `docs`, `fix`, or `chore`.
5. **Secure Local Backup & Isolation (~/.gemini/tmp):** To isolate staged commits for pristine IDE review with zero clutter, the agent MUST temporarily backup all non-layer modified and untracked files to the standard `~/.gemini/tmp/<repo-name>/backup_changes` directory.

---

## Step-by-Step Procedure

### Phase 1: Research & Reproduce
1. **Understand Goal & Hurdle:** Map the user's high-level goal and hurdle. If an existing workflow matches (e.g. CI failure matches `troubleshoot-workflows.md`), declare it explicitly.
2. **Codebase Exploration:** Search the codebase for existing patterns, conventions, and affected source/test files.
3. **Empirical Bug Reproduction:** For bug fixes, write a reproduction script or local test that demonstrates the failure, and run it to confirm the bug state.

### Phase 2: Planning & Strategy (First User Gateway)
4. **Write Unified Plan & Checklist:** Formulate and document a unified plan in `.agent/plans/<PlanName>.md` following the guidelines in `.agent/rules/plans.instructions.md` (Abstract + sequential checklist). The sequential implementation checklist MUST explicitly incorporate all standard quality gates (local build/test verification, static linters, proactive review, upstream sync, unstaged IDE review, authorized commit, and draft PR generation) so they are physically checkbox-tracked for every change.
5. **Solicit Approval:** Present the plan to the developer for explicit approval. Do NOT modify any files until they explicitly agree.

### Phase 3: Surgical Implementation (Act)
6. **Execute Plan & Track State (No Stage/Commit):** Implement the plan sequentially, updating checkboxes in the plan file in place. Keep edits simple, precise, and idiomatic. Do NOT stage (`git add`) or commit (`git commit`).
7. **Build & Test Verification:** Compile, build, and run tests locally.
   * **Full Test Suite Context Warning:** The full test suite can take over an hour and generate massive logs. Redirect output (e.g., `./run_tests.sh [options] > /tmp/run_tests.log 2>&1`) and run `.agent/skills/parse-test-logs.sh` to prevent context window flooding.
   * **Fast Verification Option:** Validate changes quickly on a single fixture:
     ```bash
     ./run_tests.sh -f sle-micro-61-canal-stable-one-rpm-ipv4
     ```
8. **Static Analysis & Linters:** Run ecosystem linters (e.g., `golangci-lint`, `shellcheck`, `tflint --recursive`, `actionlint`) and resolve all warnings.

### Phase 4: Proactive Review & Quality Gate
9. **Proactive Code Review:** Review the code diff against `.agent/rules/github-copilot-review.instructions.md`.
10. **Resolve Findings:** Refactor and fix any concerns discovered, ensuring exactly 0 automated Copilot findings.

### Phase 5: Chunking & IDE Review (Second User Gateway)
11. **Logical Partitioning:** If there is a large volume of changes, group files into focused, independent **subsystem boundaries** (layers).
12. **Upstream Synchronization:** Before checkout, switch to `main` and execute `.agent/skills/git-sync.sh` to ensure our branch off point is completely up-to-date with upstream.
13. **Isolate First Layer (Keep Unstaged):** Create a dedicated branch directly off the updated `main`. To keep the workspace clean, backup all other non-layer files to the standard `~/.gemini/tmp/<repo-name>/backup_changes` directory. Clean other files from the working directory, leaving **exclusively** the target layer's changes unstaged.
14. **Solicit Developer Feedback:** Present the unstaged diff to the developer in the chat and request their IDE review. Agree on a conventional commit message. Refine collaboratively in the IDE until approved.

### Phase 6: Logical Commit, Draft PR & PR Review (Third User Gateway)
15. **Authorized Commit & Push:** Once explicitly approved, stage and commit the isolated layer and push to origin fork. *Prefix commands with `APPROVED_BY_USER=1`.*
16. **Generate Draft PR:** Create a Draft Pull Request using `.agent/skills/create-pr.sh --draft`.
17. **Draft PR Approval:** Ask the developer to inspect the draft PR on GitHub. If changes are requested, apply and repeat the loop.
18. **Convert to Ready:** Once signed off, mark the PR as ready for review on GitHub using `gh pr ready <pr-number>`.

### Phase 7: PR Iteration & Next Layer Restoration
19. **Address Copilot Review:** Wait for automated PR checks and Copilot reviews to finish, and resolve any findings.
20. **Proceed to Next Layer:** Switch back to the synchronized `main`, restore the remaining files from the backup directory `~/.gemini/tmp/<repo-name>/backup_changes` back into the active workspace, and return to Step 11 for the next layer.
21. **Completion Summary:** Once all layers are successfully complete and merged, provide a concise summary with links to all Pull Requests.
