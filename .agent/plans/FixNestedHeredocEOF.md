# Plan: Fix Nested Heredoc Keyword Collision in Prep Scripts

**Executed Date:** pending
**Purpose:** Resolve the nested heredoc parsing failure inside HA, Splitrole, and Prod layout deployments caused by `EOT` keyword overlap between the outer `inputs` variable definition and inner script NetworkManager configuration blocks.
**Goals & Code Snippets:**
The test logs indicate that during `deploy_initial_node` execution, Terraform apply fails with:
`Error: Invalid multi-line string` and `Error: Argument or block definition required`.
This is because in `examples/ha/main.tf`, `examples/prod/main.tf`, and `examples/splitrole/main.tf`, the `inputs` variable is defined as a heredoc with an `EOT` marker:
`inputs = <<-EOT ... EOT`
Inside this heredoc, we interpolate `${local.install_prep_script}`.
The OS prep scripts contain inner `cat > ... << EOT ... EOT` blocks (specifically for Wicked and `rke2-canal.conf` network configs). Because the inner heredoc uses the SAME `EOT` marker as the outer block, Terraform's HCL parser prematurely terminates the outer `inputs` heredoc, leading to invalid syntax and crashes.
We will modify the inner heredoc marker from `EOT` to `EOF` across all affected OS prep scripts:
- SUSE/SLES (`suse_prep.sh.tftpl`, `sles_prep.sh`)
- Multi-Linux (`multi-linux_prep.sh.tftpl`, `multi-linux_prep.sh`)
- RHEL/Rocky (`rhel_prep.sh.tftpl`, `rhel_prep.sh`)
Since `EOF` is not used by any outer HCL heredoc block, this eliminates the keyword collision and resolves the parsing crashes. We have also confirmed that there are no unsafe `${...}` interpolations in these files.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixNestedHeredocEOF.md`.
- [x] Update SLES prep scripts (`examples/one/sles_prep.sh`, `examples/ha/config_files/suse_prep.sh.tftpl`, `examples/prod/config_files/suse_prep.sh.tftpl`, `examples/splitrole/config_files/suse_prep.sh.tftpl`) to use `EOF` instead of `EOT`.
- [x] Update Multi-Linux prep scripts (`examples/one/multi-linux_prep.sh`, `examples/ha/config_files/multi-linux_prep.sh.tftpl`, `examples/prod/config_files/multi-linux_prep.sh.tftpl`, `examples/splitrole/config_files/multi-linux_prep.sh.tftpl`) to use `EOF` instead of `EOT`.
- [x] Update RHEL prep scripts (`examples/one/rhel_prep.sh`, `examples/ha/config_files/rhel_prep.sh.tftpl`, `examples/prod/config_files/rhel_prep.sh.tftpl`, `examples/splitrole/config_files/rhel_prep.sh.tftpl`) to use `EOF` instead of `EOT`.
- [x] Static Validation: Run `shellcheck` on all modified files.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Execute git-sync and branch isolation.
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [x] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [x] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.
equest.
