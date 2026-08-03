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

  // We only inspect run_shell_command execution
  if (tool_name !== 'run_shell_command' || !tool_input || !tool_input.command) {
    console.log(JSON.stringify({ decision: "allow" }));
    process.exit(0);
  }

  const command = tool_input.command.trim();

  // Strip leading env var assignments (e.g. KEY=value or KEY="value" or KEY='value') and optional sudo
  let commandClean = command;
  while (true) {
    const next = commandClean.replace(/^[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|\S+)\s+/, '');
    if (next === commandClean) break;
    commandClean = next;
  }

  // Check for unauthorized git commit or push operations
  const isCommitOrPush = /\bgit\s+(commit|push)\b/.test(commandClean);
  if (isCommitOrPush) {
    const segments = command.split(/\s*(?:&&|;|\|\|)\s*/);
    const hasUserApproval = segments.every(segment => {
      const isSegmentCommitOrPush = /\bgit\s+(commit|push)\b/.test(segment);
      if (!isSegmentCommitOrPush) return true;
      const segmentClean = segment.trim();
      return /^(?:[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|\S+)\s+)*APPROVED_BY_USER=1\b/.test(segmentClean);
    });
    if (!hasUserApproval) {
      console.log(JSON.stringify({
        decision: "deny",
        reason: "Security Policy Violation: Automated git commits and pushes are strictly prohibited without manual developer review and sign-off.\n\n" +
                "To proceed with a commit or push, you MUST:\n" +
                "1. Invite the developer in the chat to review the unstaged changes in their IDE.\n" +
                "2. Obtain their explicit manual approval to perform the commit or push.\n" +
                "3. Prefix your git command with APPROVED_BY_USER=1 (e.g., `APPROVED_BY_USER=1 git commit -m ...` or `APPROVED_BY_USER=1 git push ...`).",
        systemMessage: "🔒 Security Block: Unauthorized automated git commit/push detected. Explicit developer approval required."
      }));
      process.exit(0);
    }
  }

  // Check if it is a git command and performs a remote-interacting operation
  const isGitCmd = /^(?:sudo\s+)?git\b/.test(commandClean);
  const isRemoteOp = /\b(push|pull|fetch|clone|remote)\b/.test(commandClean);

  if (isGitCmd && isRemoteOp) {
    const targetDir = tool_input.dir_path || cwd || process.cwd();

    // Check command string directly to catch inline URL references or remote additions
    // Ignore false positives from the filename "block-rancher-git.js"
    const hasRancherRef = /rancher/i.test(command.replace(/block-rancher-git\.js/g, ''));
    if (hasRancherRef) {
      console.log(JSON.stringify({
        decision: "deny",
        reason: "Security Policy Violation: Git command contains references to Rancher remote/URLs, which is strictly blocked.",
        systemMessage: "🔒 Security Block: Prohibited remote/URL reference detected."
      }));
      process.exit(0);
    }

    try {
      // Fetch remote URLs configured in this repo
      const remotesOutput = execSync('git remote -v', {
        cwd: path.resolve(targetDir),
        stdio: ['ignore', 'pipe', 'ignore']
      }).toString();

      // Check if any remote URL contains "rancher" (case-insensitive)
      if (/rancher/i.test(remotesOutput)) {
        console.log(JSON.stringify({
          decision: "deny",
          reason: "Security Policy Violation: Operations (push, pull, fetch, remote) targeting Rancher-owned remotes are strictly blocked.",
          systemMessage: "🔒 Security Block: Git remote operation against a Rancher remote is prohibited."
        }));
        process.exit(0);
      }
    } catch {
      // Ignore git command execution failures (e.g. not in a git repo) and proceed safely
    }
  }

  // Allow all other commands to proceed
  console.log(JSON.stringify({ decision: "allow" }));
  process.exit(0);
}

main();
