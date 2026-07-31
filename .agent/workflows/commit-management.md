# Workflow: Logical Commit & PR Management

This workflow defines a strict, repeatable engineering procedure for breaking down a large volume of workspace modifications into highly focused, logical commits and easy-to-review Pull Requests.

## Purpose
Large, monolithic pull requests or massive commits ("mega-commits") are difficult for human colleagues to review, increase the risk of introducing bugs, and slow down the CI/CD pipeline. 

This workflow enforces a **"Subsystem & Boundary Isolation"** protocol: AI agents must logically partition accumulated modifications, stage them selectively, invite developer IDE reviews, and commit them incrementally only after explicit manual approval.

---

## Core Mandates

1. **Zero Data Loss Guarantee:** Never run destructive git commands (such as `git reset --hard`, `git checkout .`, or `git clean -fd`) on modified workspace files unless explicitly requested by the developer, or after backing up work to a temporary branch or stash.
2. **IDE Review Priority:** The developer likes to review code changes directly in their IDE before staging, committing, or pushing. Never execute a `git commit` without presenting the exact staged diff and receiving explicit approval.
3. **No Upstream Pushes:** Never push directly to upstream "rancher" remotes. All remote operations must target the user's fork.
4. **Strict Release-Please & SemVer Rules (Product-Centric):** All draft commit messages must strictly adhere to Release-Please rules from the end-user product's perspective:
   - **`feat`** (bumping SemVer Minor) and **`refactor`/`!`** (bumping SemVer Major) MUST ONLY be used if the change directly modifies the Terraform files defining the published module itself (`main.tf` `variables.tf`, `versions.tf`, or `outputs.tf`).
   - **Internal Dev Changes:** Changes to helper scripts, CI/CD configuration, linters, internal hooks, or test suites DO NOT affect the published product. They MUST NOT use `feat`, `refactor`, or `!` types. Instead, use non-bumping types such as `build`, `ci`, `test`, `docs`, `fix`, or `chore`.
5. **Secure Local Backup & Isolation (~/.gemini/tmp):** To isolate staged commits for pristine IDE review with zero clutter, the agent MUST temporarily backup all non-staged modified and untracked files to the standard `~/.gemini/tmp/<repo-name>/backup_changes` directory. Non-staged files are then cleanly reset/removed from the active working tree, and are restored layer-by-layer as commits are approved.

---

## Detailed Step-by-Step Procedure

### 1. Analyze & Partition Changes
Examine the working tree to determine the total footprint of modifications:
```bash
git status
```
Logically group the modified and untracked files into distinct, self-contained **subsystem boundaries** or "layers". Examples of logical boundaries in this workspace:
* **Layer A: Nix Environment** (`flake.nix`, `flake.lock`)
* **Layer B: Workspace Rules & Workflows** (`AGENTS.md`, `.agent/workflows/*.md`)
* **Layer C: System Hooks & Settings** (`.agent/hooks/*.{sh,js}`, `.claude/settings.json`, `.gemini/settings.json`)
* **Layer D: Tool Skills / Utility Scripts** (`.agent/skills/*.sh`)

---

### 2. The Layer-by-Layer PR Cycle (Repeat for Each Layer)

AI agents MUST execute the following 8-step independent branch-off and PR cycle sequentially for each logical layer, ensuring that every PR is completely atomic, independent, and has **zero** dependencies on other in-flight PRs.

#### Step 1: Create a New Local Branch Directly Off Main
Before staging or applying any changes, always switch to the synchronized default `main` branch and create a new dedicated feature branch from it. This ensures that every PR depends *only* on the current up-to-date base and is completely isolated:
```bash
git checkout main
# Safely synchronize default branch with upstream first
.agent/skills/git-sync.sh
git checkout -b <new-feature-branch>
```

#### Step 2: Isolate Changes (Keep Unstaged)
To allow the developer to review the current layer's modifications in complete, pristine isolation in their IDE with full color-coded diff visibility, we keep the target files **unstaged** in the working directory:
1. **Back up non-layer files:** Copy all other modified and untracked files to the secure temporary directory `~/.gemini/tmp/<repo-name>/backup_changes` (retaining directory paths).
2. **Reset the workspace working tree:** Discard modifications to other tracked files (using `git restore` or `git checkout`) and delete other untracked/new files from the active working directory (since they are securely backed up).
3. **Verify:** Run `git status` to ensure the working tree contains **exclusively** the unstaged modifications for the current logical layer.

#### Step 3: Solicit IDE Review & Update
Present a concise summary to the user outlining the unstaged files, requesting them to perform an IDE review, and proposing a draft commit message matching the repository's convention. Apply any refinements or stylistic edits they make directly inside their IDE.

#### Step 4: Stage, Commit, and Push
Once the developer manually inspects the IDE and provides an explicit directive to commit, stage the files, run the commit, and push the branch to the developer's origin fork:
```bash
git add <file1> <file2> ...
git commit -m "fix: commit message description"
git push origin <new-feature-branch>
```

#### Step 5: Create a Draft PR
Create a Draft Pull Request targeting the upstream repository using the `.agent/skills/create-pr.sh` skill script:
```bash
.agent/skills/create-pr.sh --title "fix: description" --body "Detailed markdown body..." --draft
```

#### Step 6: Request User PR Review
Ask the user to review the newly created draft PR on GitHub to confirm the description, title, and file changes look clean.

#### Step 7: Convert to Full Review
With the developer's manual sign-off on the draft PR, convert it from a draft to a full review-ready Pull Request:
```bash
gh pr ready <pr-number>
```

#### Step 8: Proceed to the Next Layer (Independent Execution)
1. Switch back to the synchronized `main` branch.
2. Restore the remaining files from the backup directory `~/.gemini/tmp/<repo-name>/backup_changes` back into the active workspace.
3. Repeat **Steps 1 through 8** for the next logical layer. Every subsequent branch MUST be created directly from `main` to maintain absolute atomic isolation.
