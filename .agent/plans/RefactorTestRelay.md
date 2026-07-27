# Refactor Test Relay

**Executed Date:** 2026-07-22
**Purpose:** Consolidate and refactor the `test/test_relay` module to resolve CPU pinning and nested Terraform issues, and replace the `local` provider with `rancher/file`.

---

## High-Level Abstract & Goals

The `test/test_relay` module had a duplicated, highly complex double retry-apply-and-destroy loop at its outer SSH layer (`terraform_data.apply` in `test_relay/main.tf`). This outer loop would rerun `terraform apply` on the orchestrator up to 27 times under failure conditions, causing heavy nested process congestion, runner lockups, and CPU pinning issues. By simplifying the outer layer to a single-pass `terraform init && terraform apply`, we delegate failure retries directly to the orchestrator's native `create.sh` loop.

Additionally, this plan replaces the deprecated `hashicorp/local` provider with `rancher/file` to consolidate file manipulation resources and align with workspace conventions.

## Architectural Changes & Code Snippets

### 1. Removing Redundant Retry Loops
Before:
```hcl
resource "terraform_data" "apply" {
  ...
  provisioner "remote-exec" {
    inline = [<<-EOT
      # Complex double loop retrying apply up to 27 times
      while [ $EXITCODE -gt 0 ] && [ $ATTEMPTS -lt "$MAX" ]; do ... done
    EOT
    ]
  }
}
```

After:
```hcl
resource "terraform_data" "apply" {
  ...
  provisioner "remote-exec" {
    inline = [<<-EOT
      set -e
      source ~/.bashrc
      export PATH="${local.home_remote_path}/bin:$PATH"
      export TF_IN_AUTOMATION=1
      export CHECKPOINT_DISABLE=1
      export TF_PLUGIN_CACHE_DIR=${local.home_remote_path}/.terraform.d/plugin-cache
      export AGE_KEY_PATH=${local.home_remote_path}/age_key
      export AGE_RECIPIENTS_PATH=${local.home_remote_path}/age_recipients.txt
      export SECRETS_PATH=${local.home_remote_path}/secrets.rc.age

      mkdir -p ${local.home_remote_path}/.terraform.d/plugin-cache
      cd ${local.orchestrator_remote_path}

      rm -f .terraform.lock.hcl
      terraform init
      terraform apply -var-file="inputs.tfvars" -no-color -auto-approve -state="tfstate"
    EOT
    ]
  }
}
```

### 2. Transitioning to `rancher/file` Provider
To ensure local file path creation remains robust and completely avoids buggy custom provider schema validation crashes (such as computed attributes like `created` or `id` remaining unknown after a failed or aborted apply), we utilize a lightweight, platform-agnostic `local-exec` directory creation resource:

```hcl
resource "terraform_data" "create_data_local" {
  provisioner "local-exec" {
    command = "mkdir -p '${local.data_local_path}'"
  }
}
```

We then convert all `local_file` resources to `file_local` and declare a strict dependency on `terraform_data.create_data_local`:
```hcl
resource "file_local" "kubeconfig" {
  depends_on = [
    ...,
    terraform_data.create_data_local,
  ]
  contents  = replace(...)
  directory = local.data_local_path
  name      = "kubeconfig"
}
```

### 3. Provider Version Constraint Alignment
During execution, we discovered a version constraint conflict where root `versions.tf` had `rancher/file` pinned exactly to `2.2.0`, while the submodules and tests had it pinned exactly to `2.2.1`. When the fixture attempted to compile, Terraform had to resolve both constraints and failed due to the mismatch. To resolve this, we aligned the root `versions.tf` to version `"2.2.1"` to seamlessly match the rest of the repository.
