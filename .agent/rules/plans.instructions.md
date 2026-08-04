# Planning Changes

All plans MUST be documented in a single, unified plan file located under the `.agent/plans/` directory (e.g., `.agent/plans/<PlanName>.md`). We no longer use separate temporary plans in `.agent/agent-memory/`.

## Plan Document Structure

Each plan file MUST follow a strict structure consisting of two main halves:

### Top Half: High-Level Abstract & Purpose
* **Executed Date:** The date the plan was fully executed (formatted as `YYYY-MM-DD` for log sorting), or `"pending"` if execution is ongoing.
* **Purpose:** A high-level, clear abstract of the plan's goals and why these changes are being made.
* **Goals & Code Snippets:** Precise technical objectives and proposed implementation code blocks or architecture designs.

### Bottom Half: Sequential Implementation Checklist
* **Implementation Checklist:** A section named `## Implementation Checklist` containing a sequential, step-by-step implementation checklist.
* **Sequential Work Protocol:** Each step of the checklist MUST be worked strictly in turn. You are NOT allowed to skip steps or run steps in parallel if they depend on one another.
* **Update Checklist Progress:** You MUST update the plan file in place, checking off each step (e.g., `- [ ]` -> `- [x]`) **once it is completed and BEFORE starting the next step**. This ensures the plan file serves as a durable, session-persistent execution state.

### Standard Quality Gate Checklist Integration
To guarantee 100% compliance with repository engineering standards, the sequential implementation checklist of EVERY plan MUST explicitly incorporate the quality gates of our Standard Development Process (Phases 3, 4, 5, and 6) as concrete, checkbox-tracked checklist items:
1. **Implementation & Verification:** Standard build, test execution, and local static analysis/linter verification (`tflint`, `actionlint`, `shellcheck`, etc.).
2. **Proactive Code Review:** Diff validation against `github-copilot-review.instructions.md` to guarantee exactly 0 automated comments.
3. **Upstream Sync & Staging Isolation:** Switch to `main`, execute `git-sync.sh`, branch off, isolate the current layer's changes, and keep them **unstaged** in the active workspace to maintain color-coded IDE visibility.
4. **Developer IDE Review Gateway:** Invite the developer to perform their IDE review, obtain explicit manual approval, and perform the authorized conventional commit/push using `APPROVED_BY_USER=1`.
5. **PR Generation Gateway:** Create the draft Pull Request on GitHub using `create-pr.sh --draft`.
