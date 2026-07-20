#!/usr/bin/env bash
set -uo pipefail

echo "=== Running Static Analysis ==="
exit_code=0

# 1. Terraform lint
echo "--- Running Terraform format and tflint ---"
if ! (terraform fmt -check -recursive -diff && tflint --recursive); then
  echo "❌ Terraform lint failed"
  exit_code=1
else
  echo "✅ Terraform lint passed"
fi

# 2. ESLint
echo "--- Running ESLint on GitHub scripts ---"
if ! (npm install --no-save eslint @eslint/js globals && eslint .); then
  echo "❌ ESLint failed"
  exit_code=1
else
  echo "✅ ESLint passed"
fi
rm -rf node_modules

# 3. Actionlint
echo "--- Running Actionlint ---"
if ! actionlint; then
  echo "❌ Actionlint failed"
  exit_code=1
else
  echo "✅ Actionlint passed"
fi

# 4. Shellcheck
echo "--- Running Shellcheck ---"
failed_shellcheck=false
while read -r file; do
  if [ -f "$file" ]; then
    echo "checking $file..."
    if ! shellcheck -x "$file"; then
      failed_shellcheck=true
    fi
  fi
done <<<"$(grep -Rl -e '^#!' | grep -v '.terraform' | grep -v '.git')"

if [ "$failed_shellcheck" = true ]; then
  echo "❌ Shellcheck failed"
  exit_code=1
else
  echo "✅ Shellcheck passed"
fi

# 5. Gitleaks
echo "--- Running Gitleaks ---"
if ! (gitleaks detect --no-banner -v --no-git && gitleaks detect --no-banner -v); then
  echo "⚠️ Gitleaks found potential secrets (warning only to match original continue-on-error)"
else
  echo "✅ Gitleaks check passed"
fi

exit "$exit_code"
