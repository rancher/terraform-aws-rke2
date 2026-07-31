#!/usr/bin/env bash
set -euo pipefail

# Consume and discard hook input from stdin to prevent broken pipes
cat > /dev/null

# Log diagnostics to stderr to comply with the silence rule on stdout
echo "Loading session-start workspace context..." >&2

combined_context=""

if [[ -f "AGENTS.md" ]]; then
  combined_context+=$'# Context from AGENTS.md\n\n'
  combined_context+=$(cat AGENTS.md)
  combined_context+=$'\n\n'
  echo "Loaded AGENTS.md" >&2
else
  echo "Warning: AGENTS.md not found" >&2
fi

if [[ -f ".agent/workflows/development-process.md" ]]; then
  combined_context+=$'# Context from .agent/workflows/development-process.md\n\n'
  combined_context+=$(cat .agent/workflows/development-process.md)
  combined_context+=$'\n\n'
  echo "Loaded .agent/workflows/development-process.md" >&2
else
  echo "Warning: .agent/workflows/development-process.md not found" >&2
fi

# Output clean JSON structure to stdout
jq -n --arg ctx "$combined_context" '{
  "hookSpecificOutput": {
    "additionalContext": $ctx
  },
  "systemMessage": "✨ AGENTS.md and development-process.md context injected successfully."
}'
