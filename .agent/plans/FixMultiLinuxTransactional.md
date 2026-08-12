# Plan: Fix Transactional Multi-Linux Manager Server Failures

**Executed Date:** 2026-08-12
**Purpose:** Resolve the failing test `suse-multi-linux-manager-server-5-canal-stable-one-rpm-ipv4` caused by a read-only root filesystem on transactional SUSE Multi-Linux Manager systems.
**Goals & Code Snippets:**
The test logs indicate that the node prep script fails with:
`can't create transaction lock on /usr/lib/sysimage/rpm/.rpm.lock (Read-only file system)`
and `Failed to import public key`.
This is because `examples/one/multi-linux_prep.sh` executes raw `zypper` and `rpm` commands on a transactional operating system.
We will modify `examples/one/multi-linux_prep.sh` to dynamically check if `transactional-update` is available:
- If yes, execute the repository add, key-import, and package installation commands inside `transactional-update --non-interactive --continue shell <<EOF`, and schedule a reboot at the end of the script: `(sleep 2 ; reboot) &`.
- If no, run the standard direct `zypper` and `rpm` commands as before.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixMultiLinuxTransactional.md`.
- [x] Update `examples/one/multi-linux_prep.sh` to dynamically detect transactional systems, run package commands inside `transactional-update`, and schedule a reboot at the end.
- [x] Static Validation: Run `shellcheck examples/one/multi-linux_prep.sh`.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Ensure branch and changes are isolated.
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [x] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [x] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.
