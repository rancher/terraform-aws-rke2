# Plan: Fix Missing dig Command Failures on Minimal SUSE Images

**Executed Date:** pending
**Purpose:** Resolve the failing IPv6 CI tests on SLES 16/SLE Micro 6.x caused by the missing `dig` command on minimal/appliance-style SUSE environments.
**Goals & Code Snippets:**
The test logs indicate that the node prep script fails with:
`install_prep.sh: line 89: dig: command not found`
This is because modern minimal SLES 16 and transactional SLE Micro images do not pre-install the `bind-utils` package containing `dig`. Because `set -e` is active, the missing command crashes the entire provisioning script, failing the run.
We will modify all 8 occurrences of `dig AAAA google.com` across all SUSE-based prep scripts (`examples/one/sles_prep.sh`, `examples/one/multi-linux_prep.sh`, `examples/ha/config_files/suse_prep.sh.tftpl`, `examples/ha/config_files/multi-linux_prep.sh.tftpl`, `examples/prod/config_files/suse_prep.sh.tftpl`, `examples/prod/config_files/multi-linux_prep.sh.tftpl`, `examples/splitrole/config_files/suse_prep.sh.tftpl`, and `examples/splitrole/config_files/multi-linux_prep.sh.tftpl`) to safely and non-fatally test DNS resolution:
- If `dig` is available, run it.
- If `dig` is not available, print a helpful warning message and exit cleanly without crashing the script.
- We will also completely remove the `suse-multi-linux-manager-server-5` image from our Terraform variable definitions, test combinations, and test suites, as it is an appliance server and does not make sense to deploy RKE2 on.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixSlesIPv6DigNotFound.md`.
- [x] Remove `suse-multi-linux-manager-server-5` from `variables.tf` (description, allowed list, and validation blocks).
- [x] Remove `suse-multi-linux-manager-server-5` from `test/fixtures/combinations.go`.
- [x] Remove `suse-multi-linux-manager-server-5` from `test/ready_test.go`.
- [x] Update `examples/one/sles_prep.sh` with safe `dig` check and `getent` fallback.
- [x] Update `examples/one/multi-linux_prep.sh` with safe `dig` check and `getent` fallback.
- [x] Update `examples/ha/config_files/suse_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Update `examples/ha/config_files/multi-linux_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Update `examples/prod/config_files/suse_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Update `examples/prod/config_files/multi-linux_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Update `examples/splitrole/config_files/suse_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Update `examples/splitrole/config_files/multi-linux_prep.sh.tftpl` with safe `dig` check and `getent` fallback.
- [x] Static Validation: Run `shellcheck` on all modified files.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Ensure branch and changes are isolated.
- [ ] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [ ] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [ ] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.
