# Workflow: Standard Development Process

This workflow defines the standard, step-by-step procedure that all AI agents must follow when implementing features, refactoring code, or fixing bugs in this repository.

## Phase 1: Research & Reproduce

### 1. Codebase Exploration
* Search the codebase for existing design patterns, helper functions, and architectural conventions.
* Identify all files affected by the requested change (both source and tests).
* Reference the language-specific standard rules under `.agent/rules/` (such as `go.instructions.md` or `terraform.instructions.md`).

### 2. Empirical Bug Reproduction (Mandatory for Bug Fixes)
* Before writing any fix, you must reproduce the reported failure state.
* Write a localized test case or a reproduction script that demonstrates the bug.
* Run the reproduction to confirm it fails exactly as described.

---

## Phase 2: Strategy & Planning

### 1. Formulate Plan
* Design a modular, robust solution that integrates cleanly with the existing architecture.
* Prioritize explicit composition over complex inheritance.

### 2. Document the Plan
* Record a high-level plan under `.agent/plans/<PlanName>.md` (if the change is substantial—such as modifying 5+ files or >300 lines of code).
* Always build a temporary checklist plan under `.agent/agent-memory/<PlanName>_temp.md` to track progress across sessions.
* Present the plan to the user for approval before modifying files.

---

## Phase 3: Surgical Implementation (Act)

### 1. Apply Changes
* Apply targeted, precise edits to source files.
* Do not perform unrelated refactoring or "cleanups" outside of the scope of the approved plan.
* Keep edits simple, readable, and idiomatic.

### 2. Format & Compilation
* Run ecosystem formatters (e.g. `go fmt`) immediately after editing.
* Compile the project locally to verify there are no syntax or type errors.

---

## Phase 4: Testing & Documentation (Validate)

### 1. Test Verification
* Always add new automated test cases to cover the modified or new logic.
* Run unit tests to confirm correctness:
  ```bash
  ./run_tests.sh -t <TestName>
  ```
* Run local acceptance tests (excluding AWS test relay unless explicitly instructed).

### 2. Update Documentation
* If schemas, parameters, or behaviors have changed, update the markdown documentation under `docs/resources/` or `docs/data-sources/` accordingly.

---

## Phase 5: Code Quality, Proactive Review & Finalization

### 1. Lint & Static Analysis
* Run local linters (e.g. `golangci-lint`) to ensure code compliance.
* Resolve any static analysis warnings.

### 2. Proactive Code Review (Copilot Compliance)
* Prior to staging or opening a pull request, the agent MUST perform a comprehensive, single-pass proactive code review of all modified files.
* **The Goal:** Prevent any comments or findings from the automated GitHub Copilot review (achieving exactly **0 comments**).
* **Review Criteria:** Review the diff against `.agent/rules/github-copilot-review.instructions.md` and language-specific instructions. Verify:
  - **Security:** Zero leaked secrets, safe shell/exec executions, robust validation boundaries.
  - **Logic & Edge Cases:** No unhandled nil pointers, clean error propagation, comprehensive test coverages.
  - **Performance:** Inefficient loops or resource handling.
  - **Architecture:** Complete adherence to established design patterns.
* **Verification:** Present a clear, consolidated summary of the code review findings to the developer, and verify that any identified concerns are refactored before moving to the commit phase.

### 3. Summary
* Provide a concise summary of the changes made, the tests executed, and the results achieved against the plan.

---

## Phase 6: Logical Commit & PR Management

### 1. Execute Subsystem & Boundary Partitioning
* For all completed features, bug fixes, or workspace upgrades, do not commit everything in a single massive block.
* Strictly follow the [.agent/workflows/commit-management.md](commit-management.md) procedure.
* Group changed files into logical boundaries, selectively stage them, invite the developer to perform an IDE review of the staged diff, and commit only after receiving explicit manual approval.
