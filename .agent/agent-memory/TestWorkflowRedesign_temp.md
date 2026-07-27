# Temporary Plan: Test Workflow Redesign

This is the detailed file-oriented execution log and checklist for the Test Workflow Redesign plan.

## File-Oriented Checklist

### 1. `run_tests.sh`
- [ ] Implement compression routine to package the entire repository into `/tmp/${IDENTIFIER}_repo.zip`.
- [ ] Exclude large/nested files: `.git/*`, `.terraform/*`, `node_modules/*`, `test/data/*`, `test/test_relay/data/*`.
- [ ] Export `TEST_REPO_ZIP="/tmp/${IDENTIFIER}_repo.zip"` environment variable so Terratest can discover and use it.

### 2. `test/test_relay/variables.tf`
- [ ] Declare `variable "repo_zip_path"` to allow passing the local repository zip path into Terraform.

### 3. `test/test_relay/main.tf`
- [ ] Retain local and remote `age_key` / `secrets.rc.age` encryption and transmission provisioners (`terraform_data.create_age`).
- [ ] Add a `file` provisioner in a `terraform_data` block to securely copy the repo `.zip` archive to `/tmp/repo.zip` on the runner.
- [ ] Update `install_dependencies` to:
  - Install OS packages (`git`, `python3`, `tar`, `curl`, `iptables`, `unzip`).
  - Unpack `/tmp/repo.zip` into `/home/${username}/workspace`.
  - Download and install Docker (static binary method) and start `dockerd` (ensuring legacy `iptables` support).
  - Pre-pull the official `ghcr.io/rancher/ci-image/nix:20260603-18` image to optimize remote test execution.
  - Remove host-level Nix, AWS CLI, and Terraform installation steps.
- [ ] Remove all orchestrator copying, orchestrator running, local file proxying, kubeconfig copying, and certificate proxying blocks.
- [ ] Expose standard outputs: `runner_ip`, `username`.

### 4. `test/fixtures/create.go`
- [ ] Update `create(t, d)`:
  - Configure `terraformOptions.Vars` to include `"repo_zip_path" = os.Getenv("TEST_REPO_ZIP")`.
  - Execute `terraform.InitAndApply` to deploy the simplified `test_relay` (this automatically copies age secrets and unpacks the zip file).
  - Retrieve `runner_ip` and `username` from the module's outputs.
  - SSH into the runner and execute the containerized remote test, reusing `.github/workflows/scripts/nix-run.sh` to initialize the Nix development shell:
    ```bash
    docker run --rm \
      -v /home/${username}/workspace:/workspace \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -w /workspace \
      --env-file <(age -d -i /home/${username}/age_key /home/${username}/secrets.rc.age) \
      --env COMBO=${combo_name} \
      ghcr.io/rancher/ci-image/nix:20260603-18 \
      bash .github/workflows/scripts/nix-run.sh "go test -v ./test/ -run TestMatrix"
    ```
  - Capture standard out, stderr, and container exit status directly as the test outcome.
  - Remove all proxying, SSH tunnel initialization, cert scp download, and local kubeconfig modification code.

### 5. `test/fixtures/util.go`
- [ ] Update `Teardown` to destroy the simplified `test_relay` instance (which cleans up the EC2 instance, security groups, and local temp files).
- [ ] Retain AWS keypair cleanup.

---

## Detailed Execution Steps

### Step 1: Implement Packaging in `run_tests.sh`
Add the zip generation step to `run_tests.sh` before running terratest:
```bash
echo "Packaging repository for remote execution..."
IDENTIFIER="${IDENTIFIER:-tf-test}"
ZIP_FILE="/tmp/${IDENTIFIER}_repo.zip"
rm -f "$ZIP_FILE"
zip -rq "$ZIP_FILE" . -x "*.git*" "*.terraform*" "*node_modules*" "*test/data*" "*test/test_relay/data*"
export TEST_REPO_ZIP="$ZIP_FILE"
```

### Step 2: Refactor `test_relay/variables.tf` and `test_relay/main.tf`
- Add `repo_zip_path` variable.
- In `main.tf`, add:
  ```hcl
  resource "terraform_data" "copy_repo_zip" {
    depends_on = [module.runner]
    connection {
      type = "ssh"
      user = local.username
      host = module.runner.server.public_ip
      # ...
    }
    provisioner "file" {
      source      = var.repo_zip_path
      destination = "/tmp/repo.zip"
    }
  }
  ```
- Adjust `install_dependencies` to run after `copy_repo_zip` and add `unzip -oq /tmp/repo.zip -d ${local.home_remote_path}/workspace`.

### Step 3: Implement Remote Docker Execution in `create.go`
In `test/fixtures/create.go`:
- Remove all local certificate generation, proxying, and tunnel logic.
- Execute SSH command on `runner_ip` to start the Docker container inside the pre-cached `ghcr.io/rancher/ci-image/nix` environment.
