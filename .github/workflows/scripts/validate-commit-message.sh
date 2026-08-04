#!/usr/bin/env bash
set -e

# Check commit messages
# This steps enforces https://www.conventionalcommits.org/en/v1.0.0/
# This format enables automatic generation of changelogs and versioning

filter() {
  COMMIT="$1"
  # Standard conventional commits: type(scope)!: description
  # where type is fix, feat, feature, chore, docs, style, refactor, perf, test, build, ci, revert
  # scope is optional alphanumeric with dashes/underscores in parentheses
  # ! is optional indicating breaking change
  # followed by a colon and space
  # We also allow "Merge " branch messages
  if echo "$COMMIT" | grep -qE '^(build|chore|ci|docs|feat|feature|fix|perf|refactor|revert|style|test)(\([a-zA-Z0-9_-]+\))?!?: ' || grep -qE '^Merge ' <<<"$COMMIT"; then
    echo "" # Passed (empty output means success)
  else
    echo "invalid" # Failed (non-empty output means error)
  fi
}

prefix_check() {
  message="$1"
  has_core_changes="$2"
  if [ "" != "$(filter "$message")" ]; then
    cat <<EOF
...Commit message does not start with a valid conventional commit prefix.
Please use a standard conventional commit prefix (e.g., "fix:", "feat:", "chore:", "ci:", "docs:", "test:", "refactor:", "build:", "perf:", "style:", "revert:"), optionally with a scope and/or breaking change indicator '!' (e.g., "feat(api)!: description").
This enables release-please to automatically format release notes based on the commit message.
$message
EOF
    exit 1
  fi

  # If no core files (main.tf, outputs.tf, variables.tf, versions.tf) were changed,
  # 'feat', 'feature', 'refactor' or breaking change '!' are forbidden.
  if [ "$has_core_changes" = "false" ]; then
    if echo "$message" | grep -qE '^(feat|feature|refactor)(\([a-zA-Z0-9_-]+\))?!?:' || echo "$message" | grep -qE '!: '; then
      cat <<EOF
...Commit message contains a 'feat', 'feature', 'refactor', or breaking change '!' prefix, but no core module files (main.tf, outputs.tf, variables.tf, versions.tf) were changed in this PR.
Please use a non-bumping dev prefix (such as 'fix:', 'chore:', 'ci:', 'docs:', 'test:') instead, as these changes do not affect the published module.
$message
EOF
      exit 1
    fi
  fi

  echo "...Commit message passed all prefix and validation checks."
}

empty_check() {
  message="$1"
  if [ "" == "$message" ]; then
    echo "...Empty commit message."
    exit 1
  else
    echo "...Commit message isnt empty."
  fi
}

length_check() {
  message="$1"
  char_count=${#message}
  if [ "$char_count" -ge 70 ]; then
    echo "...Commit message subject line should be less than 70 characters, found $char_count."
    exit 1
  else
    echo "...Commit message subject line is less than 70 characters ($char_count)."
  fi
}

spell_check() {
  message="$1"
  if grep -e '^Merge ' <<<"$message"; then exit 0; fi
  WORDS="$(cspell stdin --quiet --words-only <<<"$message")"
  if [ "" != "$WORDS" ]; then
    echo "...Commit message contains spelling errors on: ^$WORDS\$"
    echo "...Also try updating the PR title."
    echo "...If this is a mistake, add your word to the custom_words.txt file."
    exit 1
  else
    echo "...Commit message doesnt contain spelling errors."
  fi
}

# Fetch the commit messages and changed files
PR_NUMBER="$1"
COMMIT_MESSAGES="$(gh pr view "$PR_NUMBER" --json commits | jq -r '.commits[].messageHeadline')"
CHANGED_FILES="$(gh pr view "$PR_NUMBER" --json files | jq -r '.files[].path' 2>/dev/null || echo "")"

# Determine if any core module files were changed
has_core_changes=false
while read -r file; do
  if [[ "$file" == "main.tf" || "$file" == "outputs.tf" || "$file" == "variables.tf" || "$file" == "versions.tf" ]]; then
    has_core_changes=true
    break
  fi
done <<< "$CHANGED_FILES"

echo "Commit messages found: "
echo "$COMMIT_MESSAGES"
echo "Core files changed: $has_core_changes"

while read -r message; do
  echo "checking message ^$message\$"
  empty_check "$message"
  prefix_check "$message" "$has_core_changes"
  length_check "$message"
  spell_check "$message"
  echo "message ^$message\$ passed all checks"
done <<<"$COMMIT_MESSAGES"
