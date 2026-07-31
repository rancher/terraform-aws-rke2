# Workflow: Standard Development Process

This is the standard development process. All AI agents MUST strictly read, understand, and follow this 22-step process for any session and task.

---

## The 22-Step Standard Development Process

### Phase 1: Session Goal & Workflow Mapping
1. **Understand Goal & Hurdle:** The user will present a high-level Goal for the session, sometimes accompanied by a major hurdle for context (e.g., *"We need to release the rke2 module (goal), but the release CI is failing (hurdle)"* or *"We need to refine the development process (goal)"*).
2. **Workflow Mapping:** Analyze the codebase workflows under `.agent/workflows/` and explicitly declare if any existing workflow applies to the goal or hurdle (e.g., *"the release CI is failing"* maps to `.agent/workflows/troubleshoot-workflows.md`).

### Phase 2: Planning & First User Gateway
3. **Write Unified Plan & Checklist:** Formulate and document a unified plan in `.agent/plans/<PlanName>.md` following the guidelines in `.agent/rules/plans.instructions.md`. The plan must contain a high-level abstract (top half) and a sequential implementation checklist (bottom half).
4. **Solicit Approval:** Ask the user for explicit approval to execute the plan.
5. **Plan Refinement (Gateway 1):** If the user requests changes, update the unified plan and checklist in `.agent/plans/<PlanName>.md`, then ask for approval again. **The plan is the first user gateway—do NOT execute or modify any files until the user explicitly agrees with the plan.**

### Phase 3: Sequential Implementation (Act)
6. **Execute Plan & Track State (No Stage/Commit):** Implement the approved plan, executing the checklist steps strictly sequentially. Update the checkboxes (e.g., `- [ ]` -> `- [x]`) in the plan file in place **once a step is completed and BEFORE starting the next step**. Apply targeted, precise modifications. **Do NOT stage changes (`git add`) and do NOT commit (`git commit`).**
7. **Build & Test Verification:** Test the new code locally. Ensure it compiles, builds successfully without errors, and functions as intended.
   * **Full Test Suite & Context Flooding Warning:** The full test suite is extremely large and can take an hour to complete. To prevent huge volumes of test logs from being read into memory (which will flood your context window and waste tokens), **never** run `./run_tests.sh` without output redirection.
   * **Output Redirection & Parsing:** Redirect standard output and error to a temporary log file (e.g., `./run_tests.sh [options] > /tmp/run_tests.log 2>&1`), and then run `.agent/skills/parse-test-logs.sh` to extract pass/fail summaries and find any errors.
   * **Fast Verification Option:** If you are not ready to run the full suite and want to validate your changes quickly using a simple fixture, run the test on a single fixture:
     ```bash
     ./run_tests.sh -f sle-micro-61-canal-stable-one-rpm-ipv4
     ```
   * Run project-specific linters (e.g., `golangci-lint` or other ecosystem checks).

### Phase 4: Proactive Review & Quality Gate
8. **Enter Proactive Review Mode:** Critically review the written code diff with the goal of proactively identifying and resolving any issues that GitHub Copilot's automated review might flag.
9. **Resolve Review Issues:** Refactor and fix any issues discovered during your proactive review.

### Phase 5: Chunking & Second User Gateway
10. **Logical Chunking:** Break down the accumulated changes into independent, easily reviewable chunks (layers). Use the secure temporary backup directory `~/.gemini/tmp` to back up and park the chunked changes. *Note: You may use a single chunk if the total change footprint is already small.*
11. **Branch Isolation:** Switch to the synchronized `main` branch, ensure it is up to date, and create a new dedicated branch for the first chunk.
12. **Apply First Chunk (Unstaged):** Copy the first chunk's files back into the active workspace, leaving them **unstaged** in the working directory to maintain color-coded IDE visibility.
13. **Solicit Developer Feedback:** Present the unstaged diff to the developer in the chat and request their feedback. **Do NOT stage and do NOT commit.**
14. **Collaborative Refinement (Gateway 2):** The user may provide feedback, ask for more details, or make changes themselves directly in their IDE. Refine and update the code collaboratively with the user. **User review is the second user gateway—you MUST NOT proceed until the user is satisfied with the code.**

### Phase 6: Commit, Draft PR & Third User Gateway
15. **Authorized Commit & Push:** Once the user explicitly approves the code in the chat, stage (`git add`), commit, and push the changes to the user's fork repository. *Note: Prefix your `git commit` and `git push` commands with `APPROVED_BY_USER=1` to satisfy the tool-level safety hook.*
16. **Generate Draft PR:** Create a Draft Pull Request targeting the upstream repository using the `.agent/skills/create-pr.sh` skill. The PR must be created in **draft mode** (`--draft`). If a full PR has already been generated previously, skip directly to Step 19.
17. **PR Approval (Gateway 3):** Request the user to review the draft PR on GitHub. If the user requests any changes, **return to Step 13** of this process. **Approving the draft PR is the third user gateway—you MUST NOT proceed until the user approves the PR.**

### Phase 7: Verification, Copilot Compliance & Iteration
18. **Publish PR:** Once the user approves the draft PR, convert it to a full review-ready PR (`gh pr ready <pr-number>`) and request/trigger GitHub Copilot review.
19. **Wait for Copilot Review:** Wait for the automated Copilot review process to complete on the PR.
20. **Resolve Copilot Concerns:** Address any Copilot review findings or comments by following the `resolve-pr-reviews` workflow. **If any code changes are necessary, return to Step 13 of this process (which triggers the feedback loop). If code changes are ever necessary after Step 13, always return to Step 13.**
21. **Move to Next Chunk:** Once all Copilot review concerns are fully resolved and the PR is ready for human team review, move to the next logical chunk of code. **Return to Step 11** to process the next chunk.
22. **Completion Summary:** Once all logical chunks have been merged or are ready for team review, the process is complete. Inform the user with a concise summary of all completed work, including direct links to the generated Pull Requests.
