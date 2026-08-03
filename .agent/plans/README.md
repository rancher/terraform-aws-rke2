# Plans

This directory holds past plans used to refactor and standardize this repository.
The goal of this directory is to be used to understand the goals and architectural decisions behind some of the most major changes.

Plans should enable the goals set forward in the .agent/rules/standards.md file.
When creating a plan, please make sure to update the standards to reflect the goals of that plan.

Plans should only reflect major changes to the codebase, we don't need plans for everything, only major refactors or new processes.

This prompt can help when importing a plan from another repository:

```
Please take a look at <plan>.md, which I copied from another repository. We need to apply this plan to this repo. Our previous attempt at this failed midway through. Please verify what has been done and construct a unified plan in `.agent/plans/<PlanName>.md`. The plan must contain a high-level abstract (top half) and a sequential, step-by-step implementation checklist (bottom half) to track progress. Do not execute the plan yet; I want to review it first.
```
