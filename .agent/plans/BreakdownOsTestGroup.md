# Plan: Breakdown OS Test Group by OS Producer to Optimize Release CI

- **Executed Date:** pending
- **Purpose:** Optimize the CI runtime of the `os` test group by splitting it into five parallel groups by producer and type: `suse`, `ibm` (RHEL), `cis` (CIS RHEL), `ubuntu`, and `rocky`. This prevents the single `os` group matrix from bottlenecking the release and test pipelines.

---

## Goals & Proposed Changes

### 1. Define OS Producer Subgroups in Go Tests
- **Design:** In `test/ready_test.go`, break down the existing `os` tests into five specific arrays using the provided cross-reference:
  - **`suseTests`**: Includes `sle-micro-61-canal-stable-one-rpm-ipv4`, `sles-16-canal-stable-one-rpm-ipv4`, and `suse-multi-linux-manager-server-5-canal-stable-one-rpm-ipv4` (moved from `extendedTests`).
  - **`ibmTests`**: Includes `rhel-9-canal-stable-one-rpm-ipv4`.
  - **`cisTests`**: Includes `cis-rhel-9-canal-stable-one-rpm-ipv4`.
  - **`ubuntuTests`**: Includes `ubuntu-24-canal-stable-one-tar-ipv4` and `ubuntu-22-canal-stable-one-tar-ipv4`.
  - **`rockyTests`**: Includes `rocky-9-canal-stable-one-rpm-ipv4` (moved from `extendedTests`).
- **Backward Compatibility:** Redefine `osTests` as the union of these five subgroups so that anyone running the `os` group locally continues to execute all of them:
  ```go
  osTests := append([]string{}, suseTests...)
  osTests = append(osTests, ibmTests...)
  osTests = append(osTests, cisTests...)
  osTests = append(osTests, ubuntuTests...)
  osTests = append(osTests, rockyTests...)
  ```
- **Union Alignment:** Update `necessaryTests` to append `suseTests`, `ibmTests`, `cisTests`, `ubuntuTests`, and `rockyTests` instead of the old `osTests`.
- **Group Environment Support:** Update the switch case in `TestMatrix` to support:
  - `case "suse": selection = suseTests`
  - `case "ibm": selection = ibmTests`
  - `case "cis": selection = cisTests`
  - `case "ubuntu": selection = ubuntuTests`
  - `case "rocky": selection = rockyTests`
  - `case "os"` remains supported for backward compatibility.
- **Error Handling:** Update the invalid group error message to list the new groups.

### 2. Parallelize the Matrix in GitHub Actions Workflows
- **Design:** In `.github/workflows/test.yaml` and `.github/workflows/release.yaml`, update the `matrix.group` array to replace `os` with `suse`, `ibm`, `cis`, `ubuntu`, and `rocky`.
  - Old: `group: [os, cni, version, ipfamily, layout]`
  - New: `group: [suse, ibm, cis, ubuntu, rocky, cni, version, ipfamily, layout]`

---

## Implementation Checklist

### Phase 1: Surgical Implementation (Act)
- [x] Refactor `test/ready_test.go` to support `suse`, `ibm`, `cis`, `ubuntu`, and `rocky` groups while preserving backward compatibility for `os`, moving `rocky-9-canal-stable-one-rpm-ipv4` from `extendedTests` to `rockyTests`, and moving `suse-multi-linux-manager-server-5-canal-stable-one-rpm-ipv4` from `extendedTests` to `suseTests`.
- [x] Update `.github/workflows/test.yaml` to matrix-parallelize across `suse`, `ibm`, `cis`, `ubuntu`, `rocky` instead of `os`.
- [x] Update `.github/workflows/release.yaml` to matrix-parallelize across `suse`, `ibm`, `cis`, `ubuntu`, `rocky` instead of `os`.

### Phase 2: Static Analysis & Validation
- [x] Run local Go compile check (`go test -c ./test/... -o /dev/null`).
- [x] Run `actionlint` on `.github/workflows/test.yaml` and `.github/workflows/release.yaml`.
- [x] Run ecosystem linters (`golangci-lint`, etc.) to ensure full compliance.

### Phase 3: Proactive Review & Quality Gate
- [ ] Perform a proactive code review of the changes against `.agent/rules/github-copilot-review.instructions.md` to ensure exactly 0 findings.

### Phase 4: Chunking & IDE Review (User Gateway)
- [x] Clear any other non-layer files, leaving our changes unstaged.
- [x] Present the unstaged diff to the developer and request their manual IDE review.
- [x] Agree on a conventional commit message.

### Phase 5: Authorized Commit, Draft PR & PR Review (User Gateway)
- [x] Perform the authorized commit and push to origin fork with prefix `APPROVED_BY_USER=1`.
- [x] Generate the Draft Pull Request using `.agent/skills/create-pr.sh --draft`.
- [x] Request developer sign-off on the draft PR, address any Copilot reviews, and convert to ready.
