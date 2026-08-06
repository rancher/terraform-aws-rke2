# Plan: Troubleshoot SLE Micro 6.1 Package Installation and Parallelize Test Suite Matrix

- **Executed Date:** 2026-08-05
- **Purpose:** Investigate and resolve the SLE Micro package installation cpio unpacking failure by eliminating Leap package manager conflicts, and optimize the test matrix to run targeted subgroups in parallel GitHub Actions matrix jobs with run-again self-healing.

---

## Goals & Proposed Changes

### 1. Resolve SLE Micro Package Installation Bug Safely
- **Bug Root Cause:** On transactional SLE Micro 6.0/6.1, `policycoreutils` and `curl` are already pre-installed as part of the immutable OS base. In `examples/one/sle-micro_prep.sh`, the script adds openSUSE Leap 15.x repositories and executes `zypper install restorecond policycoreutils curl`. This causes `zypper` to attempt to overwrite base system files under `/usr` (e.g. `/usr/sbin/load_policy`) with packages from a different operating system (Leap), leading to `cpio: open failed - No such file or directory`.
- **Proposed Solution:** Modify `examples/one/sle-micro_prep.sh` to only install `restorecond`. This avoids package manager conflicts and successfully provisions the node while preserving full SELinux enforcement for production readiness. We will validate that `sle-micro-61` successfully boots and runs RKE2 with this change before completing verification.

### 2. Introduce Targeted Test Groups
- **Design:** In `test/ready_test.go`, partition `necessaryTests` into distinct, focused subgroups:
  - **`os`**: Verifies core OS platform boots (including `sle-micro-61`, `sles-16`, `cis-rhel-9`, `ubuntu-24`, etc.).
  - **`cni`**: Verifies CNI plugins (Cilium, Calico).
  - **`version`**: Verifies latest/old versions of RKE2.
  - **`ipfamily`**: Verifies IPv6 and Dualstack configurations.
  - **`layout`**: Verifies layouts (HA, Splitrole, Prod).
- **Optimization:** We will prefer fast-provisioning `sles-16` (no reboots required) for dimensional tests (`cni`, `version`, `ipfamily`, `layout`) and retain core SLE Micro 6.1 validation in the `os` group. The original `sle-micro-61` dimensional tests will be moved to `extendedTests` to preserve exhaustive release coverage.

### 3. Parallelize GitHub Actions Matrix with Self-Healing (Run-Again)
- **Design:** In `.github/workflows/test.yaml` and `.github/workflows/release.yaml`, convert the single sequential `test` job into a matrix job over the five targeted groups:
  ```yaml
  strategy:
    fail-fast: false
    matrix:
      group: [os, cni, version, ipfamily, layout]
  ```
- **Self-Healing:** Pass the run-again flag `-r` along with `-s` and `-g <group>` to the `./run_tests.sh` execution. If a test fails due to transient AWS network issues, it will automatically rerun once before reporting failure.

---

## Implementation Checklist

### Phase 1: Surgical Implementation (Act)
- [x] Update `examples/one/sle-micro_prep.sh` to only install `restorecond` via `zypper`.
- [x] Refactor `test/ready_test.go` to define and support the new targeted subgroups (`osTests`, `cniTests`, `versionTests`, `ipfamilyTests`, `layoutTests`), updating `necessaryTests` and `extendedTests` arrays.
- [x] Update `.github/workflows/test.yaml` to matrix-parallelize across groups and append the `-r` rerun flag.
- [x] Update `.github/workflows/release.yaml` to matrix-parallelize across groups and append the `-r` rerun flag.

### Phase 2: Static Analysis & Validation
- [x] Run local compile check (`go test -c ./test/... -o /dev/null`).
- [x] Run `shellcheck` on `examples/one/sle-micro_prep.sh` to ensure script correctness.
- [x] Run `actionlint` on `.github/workflows/test.yaml` and `.github/workflows/release.yaml`.
- [x] Run ecosystem linters (`eslint`, `tflint --recursive`, `golangci-lint`) to ensure full compliance.

### Phase 3: Proactive Review & Quality Gate
- [x] Perform a proactive code review of the unstaged changes against `.agent/rules/github-copilot-review.instructions.md`.

### Phase 4: Chunking & IDE Review (Gateway)
- [x] Switch to `main` and execute `.agent/skills/git-sync.sh` to synchronize off-point with upstream.
- [x] Isolate target changes, keeping them **unstaged** in the active workspace.
- [x] Present the unstaged diff to the developer in chat and obtain explicit IDE review approval.

### Phase 5: Authorized Commit & PR (Gateway)
- [x] Stage and commit target changes, prefixing the command with `APPROVED_BY_USER=1`.
- [x] Generate a Draft PR on GitHub using `.agent/skills/create-pr.sh --draft`.
