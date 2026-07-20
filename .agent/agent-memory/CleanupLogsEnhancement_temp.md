# Temporary Plan: Enhance cleanup.sh with Modularity and Pre-flight Defaults

This temporary plan outlines the step-by-step file-oriented execution for refactoring `cleanup.sh` to meet safety, modularity, and repository-wide automation standards.

## 1. Create Refactored cleanup.sh

- [x] **Refactor `cleanup.sh`**
  - Change shebang to `#!/usr/bin/env bash` and enable strict execution options (`set -euo pipefail`).
  - Implement colorized logging helper functions (`log_info`, `log_success`, `log_warning`, `log_error`).
  - Modularize the script by breaking up monolithic segments into discrete functions:
    - `clear_leftovers(id)`
    - `clear_secrets(id)`
    - `clear_s3_buckets(id)`
    - `clear_key_pairs(id)`
    - `clear_server_certificates(id)`
    - `clear_target_groups(id)`
    - `cleanup_resources(id)`
  - Implement standard-compliant fallback mechanism: If no cleanup ID is provided as an argument, scan AWS tags for `"Owner" = "terraform-ci@suse.com"` to identify matching IDs.
  - Implement proper variable quoting throughout the script to satisfy shellcheck.

## 2. Verification and Validation

- [x] **Run bash syntax validation**
  - Verify syntax using `bash -n`.
- [x] **Run static check/linting**
  - Run `shellcheck` to ensure 100% compliance.
