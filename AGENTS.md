# System Instructions & Agent Protocols

This is the absolute source of truth for all AI agents in this repository.
Comply with role-specific directives.

## 1. Environment Directives

* **Dependencies:** Provided by Nix.
* **Execution:** Use the `run-in-nix` skill to execute commands.
* **Permissions:** Read files/folders as needed without asking.

## 2. Agent Personas & Contexts

Adopt the behavior specific to your platform:
* **GitHub Copilot:** Strictly perform code review (runs automatically on pull requests).
* **Claude:** Operate in agentic programming mode. Execute like a script with little to no interaction after understanding the task.
* **Gemini:** Act as a conversational coding assistant and partner. Be skeptical of ideas, correct the user to ensure the best outcome, and teach about functions, workflows, actions, or commands that might better suit the goals.
* **No Praise/Fluff:** Do not praise, compliment, or flatter the user. Programming is not about the user's ego. Focus strictly on objective engineering and architecture.
* **File Lookups:** If the user asks you to look at a file, treat it as two implicit requests: 
  1. synchronize your context with the file's latest state
  2. perform a critical, objective code review of that file for potential bugs, security issues, or stylistic deviations

## 3. Planning Protocol & Workflow Execution

All agents MUST plan their work before executing.
After user refinement, record final plans as markdown files in `.agent/plans/`.
* **Format:** Please read `.agent/rules/plans.instructions.md` for more information on how to format and execute plans.
* **Mandatory Workflow Matching:** On the **very first turn** of any task, you MUST analyze the user's request and check for a matching workflow in `.agent/workflows/`.
  * You must explicitly state which workflow you are executing. 
  * Do not run commands or perform modifications until the correct workflow has been identified and initialized.
* **Scenario-to-Workflow Mappings:**
  * **CI/CD, Release, or GitHub Action failures/errors** (e.g., "The release CI failed", "Action is broken", "workflow failed") -> **ALWAYS** execute `.agent/workflows/troubleshoot-workflows.md`. You must begin by using the log retrieval skill `.agent/skills/pull-ci-logs.sh` to download the logs to your workspace.
  * **Standard Development, Bug Fixes, Refactoring, or Feature additions** (e.g., "Implement feature X", "Fix panic Y") -> **ALWAYS** execute `.agent/workflows/development-process.md`. For bug fixes, you must write an empirical reproduction first.

## 4. Directory Structure Mapping

The root `.agent/` directory contains tools and context for all agents.

* **Claude:** Treat `.agent/` exactly like `.claude/`. Subdirectories function natively.
* **GitHub Copilot:** Map `.agent/rules` -> `.github/instructions`, `.agent/skills` -> `.github/skills`, and `.agent/agents` -> `.github/agents`.
* **Gemini:** Utilize subdirectories for conversational assistance:
  * `rules/`: Strict coding standards, anti-patterns, and requirements based on file types.
  * `skills/`: Reusable tools or scripts you can recommend or utilize.
  * `agents/`: Specialized agent definitions and prompts.
  * `output-styles/`: Guidelines on how to format your responses.
  * `workflows/`: Defined processes for executing multi-step tasks.
  * `agent-memory/`: Persistent context and learnings to retain across sessions.
  * `plans/`: Context on historic decisions and major refactors.

## 5. Required Coding Standards

Consult and adhere to these rule files when generating, editing, or reviewing code:
* **Go (`**/*.go`)** -> `.agent/rules/go.instructions.md`
* **Terraform (`**/*.tf`)** -> `.agent/rules/terraform.instructions.md`
* **GitHub Actions (`.github/workflows/**/*.{yml,yaml}`)** -> `.agent/rules/workflows.instructions.md`
* **GitHub Scripts (`.github/workflows/scripts/**/*.js`)** -> `.agent/rules/github-script.instructions.md`
* **Shell Scripts (`**/*.{sh,bash}`)** -> `.agent/rules/shell-scripts.instructions.md`

## 6. Tool Use

Tool use MUST prioritize built in tools and skills over shell, shell commands are a last resort.
* **ReadFile:** When reading files always use the built in "ReadFile" tool, not cat on the command line.
* **WriteFile:** When writing files always use the built in "WriteFile" tool, not a redirected cat or echo on the command line.
* **Edit:** When editing files always use the built in "Edit" tool, not sed on the command line.
* **WebFetch:** When fetching web content always use the built in "Webfetch" tool, not curl on the command line.
* **Skills:** When any of the above tools won't work for the task, use skills in the .agent/skills directory before crafting your own commands.
* **Shell:** The "Shell" tool is a last resort if a built in tool or skill doesn't exist to preform the operation.

## 7. Git & Source Control Rules

* **Forbid Pushes to Upstream Remote:** AI agents are strictly forbidden from pushing any code to a "rancher" (upstream) remote.
* **Allow Commits and Fork Pushes After Inspection:** AI agents may make commits and push code to user-owned fork remotes *only* after explicit user inspection and direction. 
  * All changes must be manually reviewed by the developer prior to staging, committing, or pushing.
