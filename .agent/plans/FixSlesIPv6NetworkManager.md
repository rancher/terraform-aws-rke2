# Plan: Fix SLES 16 / SLE Micro 6.x IPv6 NetworkManager Configuration

**Executed Date:** 2026-08-12
**Purpose:** Resolve the failing IPv6 CI tests on SLES 16 (`sles-16-canal-stable-one-rpm-ipv6`) caused by missing Wicked/ifcfg networking directory structures on NetworkManager-based modern SUSE environments.
**Goals & Code Snippets:**
The test logs indicate that the node prep script fails with:
`/home/tf-.../install_prep.sh: line 26: /etc/sysconfig/network/ifcfg-eth0: No such file or directory`
This is because modern SLES 16 and transactional SLE Micro 6.x images have migrated to NetworkManager by default and do not contain the `/etc/sysconfig/network` directory.
We will modify the IPv6 section of all SUSE-based prep scripts (`examples/one/sles_prep.sh`, `examples/one/multi-linux_prep.sh`, `examples/ha/config_files/suse_prep.sh.tftpl`, `examples/prod/config_files/suse_prep.sh.tftpl`, and `examples/splitrole/config_files/suse_prep.sh.tftpl`) to dynamically detect the network manager:
- If NetworkManager is available (i.e. `nmcli` or `/etc/NetworkManager` exists), we write a clean `.nmconnection` file to `/etc/NetworkManager/system-connections/$DEVICE.nmconnection`, reload connections, and restart NetworkManager.
- If Wicked is used, we fall back to the standard `/etc/sysconfig/network/ifcfg-eth0` configuration.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixSlesIPv6NetworkManager.md`.
- [x] Update `examples/one/sles_prep.sh` to dynamically detect and configure NetworkManager or Wicked for IPv6.
- [x] Update `examples/one/multi-linux_prep.sh` to dynamically detect and configure NetworkManager or Wicked for IPv6.
- [x] Update `examples/ha/config_files/suse_prep.sh.tftpl` to dynamically detect and configure NetworkManager or Wicked for IPv6.
- [x] Update `examples/prod/config_files/suse_prep.sh.tftpl` to dynamically detect and configure NetworkManager or Wicked for IPv6.
- [x] Update `examples/splitrole/config_files/suse_prep.sh.tftpl` to dynamically detect and configure NetworkManager or Wicked for IPv6.
- [x] Static Validation: Run `shellcheck` on all modified shell scripts.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Ensure branch and changes are isolated.
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [x] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [x] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.
