# Plan: Fix SLES / SUSE Prep Script Heredoc Nesting Collision

**Executed Date:** pending
**Purpose:** Resolve the nested heredoc parsing failure inside HA, Splitrole, and Prod layout deployments caused by `EOT` keyword overlap between outer variables definition and inner script NetworkManager configuration writes.
**Goals & Code Snippets:**
The test logs indicate that during `deploy_initial_node` execution, Terraform apply fails with:
`Error: Invalid multi-line string` and `Error: Argument or block definition required`.
This is because in `examples/ha/main.tf`, `examples/prod/main.tf`, and `examples/splitrole/main.tf`, the `inputs` variable is defined as a heredoc with `EOT` marker:
`inputs = <<-EOT ... EOT`
And inside this heredoc, we interpolate `${local.install_prep_script}`.
Because the newly added NetworkManager configuration block inside the SUSE prep scripts writes files using an inner heredoc with the SAME `EOT` marker:
`cat > ... << EOT ... EOT`
Terraform's HCL parser prematurely terminates the outer `inputs` heredoc at the inner `EOT` marker, leading to invalid syntax and crashes.
We will modify the inner heredoc marker from `EOT` to `EOF` across all 5 SUSE-based prep scripts (`examples/one/sles_prep.sh`, `examples/one/multi-linux_prep.sh`, `examples/ha/config_files/suse_prep.sh.tftpl`, `examples/prod/config_files/suse_prep.sh.tftpl`, and `examples/splitrole/config_files/suse_prep.sh.tftpl`). Since `EOF` is not used by any outer HCL heredoc block (they use `EOT` and `EOD`), this completely eliminates any keyword collisions and resolves all parsing crashes.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixSlesHeredocCollision.md`.
- [x] Add `sles` to `custom_words.txt` to resolve `cspell` commit-message validation errors.
- [x] Update `examples/one/sles_prep.sh` to use `EOF` instead of `EOT` for inner NetworkManager configurations.
- [x] Update `examples/one/multi-linux_prep.sh` to use `EOF` instead of `EOT` for inner NetworkManager configurations.
- [x] Update `examples/ha/config_files/suse_prep.sh.tftpl` to use `EOF` instead of `EOT` for inner NetworkManager configurations.
- [x] Update `examples/prod/config_files/suse_prep.sh.tftpl` to use `EOF` instead of `EOT` for inner NetworkManager configurations.
- [x] Update `examples/splitrole/config_files/suse_prep.sh.tftpl` to use `EOF` instead of `EOT` for inner NetworkManager configurations.
- [x] Static Validation: Run `shellcheck` on all modified files.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Upstream Sync & Staging Isolation: Ensure branch and changes are isolated.
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [x] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [x] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.
