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
