#!/usr/bin/env node
import fs from 'fs';
import { execSync } from 'child_process';
import path from 'path';

function main() {
  let inputData;
  try {
    inputData = JSON.parse(fs.readFileSync(0, 'utf-8'));
  } catch (err) {
    console.error("Failed to parse stdin JSON:", err);
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }

  const { tool_name, tool_input, cwd } = inputData;

  // We only inspect write_file and replace
  if (tool_name !== 'write_file' && tool_name !== 'replace') {
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }

  const filePath = tool_input.file_path;
  if (!filePath) {
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }

  // Resolve absolute path to check if it's within .agent/, .gemini/, or .claude/
  const resolvedPath = path.resolve(cwd || process.cwd(), filePath);
  const relativePath = path.relative(cwd || process.cwd(), resolvedPath);
  const relativePathNormalized = relativePath.replace(/\\/g, '/');

  // If the file is inside the .agent, .gemini, or .claude directories, we always allow.
  if (
    relativePathNormalized.startsWith('.agent/') ||
    relativePathNormalized.startsWith('.gemini/') ||
    relativePathNormalized.startsWith('.claude/') ||
    relativePathNormalized === 'AGENTS.md' ||
    relativePathNormalized === 'GEMINI.md'
  ) {
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }

  // Check if there is an active/modified plan in git status
  try {
    const statusOutput = execSync('git status --porcelain', {
      cwd: cwd || process.cwd(),
      stdio: ['ignore', 'pipe', 'ignore']
    }).toString();

    // Check if git status has any modified (M), added (A), or untracked (??) plan files in .agent/plans/
    const hasActivePlan = statusOutput.split('\n').some(line => {
      const trimmed = line.trim();
      if (!trimmed.includes('.agent/plans/')) return false;
      const status = line.substring(0, 2);
      // Ensure the file is not deleted ('D') or ignored ('!')
      return !status.includes('D') && !status.includes('!');
    });

    if (!hasActivePlan) {
      console.log(JSON.stringify({
        decision: "deny",
        reason: "Security Policy Violation: Modifying source code is strictly prohibited without an active plan.\n\n" +
                "In accordance with 'development-process.md', you MUST first create or update a unified plan in '.agent/plans/' before applying edits to source files.\n\n" +
                "To proceed:\n" +
                "1. Create or update a unified plan (e.g. '.agent/plans/MyTask.md') containing a high-level abstract (top half) and a step-by-step '## Implementation Checklist' (bottom half).\n" +
                "2. Obtain developer approval for your plan.\n" +
                "3. Once the plan file is created (and visible in `git status`), you will be allowed to modify source files.",
        systemMessage: "🔒 Security Block: No active plan found. Please create/update a plan under .agent/plans/ first."
      }));
      process.exit(0);
    }
  } catch {
    // If not in a git repo or git status fails, allow to avoid blocking environments where git is unavailable
  }

  console.log(JSON.stringify({ decision: "allow" }));
  process.exit(0);
}

main();
