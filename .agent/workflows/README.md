# AI Agent Workflows

This directory contains defined, step-by-step procedures that AI agents must follow when executing complex, multi-step tasks in this repository. 

Using these workflows ensures maximum consistency, rigorous quality control, and clean engineering practices.

## Available Workflows

### 1. [Standard Development Process](development-process.md)
* **Purpose:** Outlines the lifecycle for developing new features, applying bug fixes, and performing refactoring.
* **Key Steps:** Exploration, bug reproduction, plan-creation, surgical edits, format/compiles, unit testing, schema documentation updates, and lint validations.

### 2. [Troubleshooting CI/CD Workflows](troubleshoot-workflows.md)
* **Purpose:** Explains how to diagnose, triage, and repair broken GitHub Actions or release workflows.
* **Key Steps:** Log retrieval, error isolation, script/YAML auditing, secret token sanitization, and verification with `actionlint` and `shellcheck`.

### 3. [Logical Commit & PR Management](commit-management.md)
* **Purpose:** Defines the procedure for breaking down large workspace changes into smaller, logically partitioned commits and pull requests.
* **Key Steps:** Subsystem analysis, selective file staging, developer IDE review presentation, and incremental committing upon explicit approval.
