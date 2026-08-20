# Plan: Fix Prep Script Multi-line String Parsing Issue in Inputs

**Executed Date:** pending
**Purpose:** Resolve the `Quoted strings may not be split over multiple lines` parsing failure inside HA, Splitrole, and Prod layout deployments by changing the double-quoted `install_prep_script` assignment to an inner heredoc.
**Goals & Code Snippets:**
In `examples/ha/main.tf`, `examples/splitrole/main.tf`, and `examples/prod/main.tf`, change the assignment:
```hcl
    install_prep_script         = "${local.install_prep_script}"
```
to:
```hcl
    install_prep_script         = <<-EOD
    ${local.install_prep_script}
    EOD
```
This produces valid HCL heredoc syntax in the temporary `inputs.tfvars` file, allowing multi-line scripts to be parsed correctly.

## Implementation Checklist
- [x] Write this approved plan to `.agent/plans/FixPrepScriptMultiLineString.md`.
- [x] Update `examples/ha/main.tf` to use the inner `EOD` heredoc for `install_prep_script` in both `deploy_initial_node` and `deploy_other_nodes`.
- [x] Update `examples/splitrole/main.tf` to use the inner `EOD` heredoc for `install_prep_script` in both `deploy_initial_node` and `deploy_other_nodes`.
- [x] Update `examples/prod/main.tf` to use the inner `EOD` heredoc for `install_prep_script` in both `deploy_initial_node` and `deploy_other_nodes`.
- [x] Proactive Code Review: Ensure diff aligns with `github-copilot-review.instructions.md`.
- [x] Local Test Verification Gateway: Propose the fast layout fixture `sles-16-canal-stable-ha-rpm-ipv4` and invite the developer to run the test locally before we push/commit.
- [x] Staging Isolation: Create a dedicated branch off main (after merging the previous PR).
- [x] Developer IDE Review Gateway: Present the unstaged diff and commit message to the developer, and obtain explicit manual approval.
- [ ] Authorized Commit & Push: Commit and push the changes with the `APPROVED_BY_USER=1` prefix.
- [ ] PR Generation Gateway: Run `create-pr.sh --draft` to raise the draft pull request.