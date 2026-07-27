# Temporary Plan: Test Workflow Redesign (Completed)

This is the detailed file-oriented execution log and checklist for the Test Workflow Redesign plan, completed and aligned with our finished codebase structure.

## File-Oriented Checklist

### 1. `run_tests.sh`
- [x] Implement compression routine to package the entire repository into `/tmp/${IDENTIFIER}_repo.tar.gz`.
- [x] Exclude large/nested files: `.terraform/*`, `node_modules/*`, `test/data/*`, `test/test_relay/data/*`.
- [x] Export `TEST_REPO_ZIP="/tmp/${IDENTIFIER}_repo.tar.gz"` environment variable so Terratest can discover and use it.

### 2. `test/test_relay/variables.tf`
- [x] Declare `variable "repo_archive_path"` to allow passing the local repository archive path into Terraform.

### 3. `test/test_relay/main.tf`
- [x] Retain local and remote `age_key` / `secrets.rc.age` encryption and transmission provisioners (`terraform_data.create_age`).
- [x] Add a secure `file` copying mechanism using `rancher/file` provider inside `test_relay` variables/main.tf.
- [x] Update `install_dependencies` to:
  - Install OS packages (`git`, `tar`, `curl`, `iptables`, `jq`).
  - Unpack the archive into `/home/${username}/workspace`.
  - Download and install Docker (static binary method) and start `dockerd` (ensuring legacy `iptables` support).
  - Pre-pull the official `ghcr.io/rancher/ci-image/nix:20260603-18` image to optimize remote test execution.
  - Remove host-level Nix, AWS CLI, and Terraform installation steps.
- [x] Remove all orchestrator copying, orchestrator running, local file proxying, kubeconfig copying, and certificate proxying blocks.
- [x] Expose standard outputs: `runner_ip`, `username`.

### 4. `test/fixtures/create.go`
- [x] Update `create(t, d)`:
  - Configure `terraformOptions.Vars` to include `"repo_archive_path" = os.Getenv("TEST_REPO_ZIP")`.
  - Execute `terraform.InitAndApply` to deploy the simplified `test_relay` (this automatically copies age secrets and unpacks the zip file).
  - Retrieve `runner_ip` and `username` from the module's outputs.
  - SSH into the runner and execute the containerized remote test, utilizing standard host networking:
    ```bash
    docker run --rm \
      --network host \
      -v /home/${username}/workspace:/workspace \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -w /workspace \
      --env IDENTIFIER=${id} \
      ghcr.io/rancher/ci-image/nix:20260603-18 \
      bash .github/workflows/scripts/nix-run.sh "go test -v ./test/ -run TestMatrix"
    ```
  - Capture standard out, stderr, and container exit status directly as the test outcome (utilizing real-time SSH streaming).
  - Remove all proxying, SSH tunnel initialization, cert scp download, and local kubeconfig modification code.

### 5. `test/fixtures/util.go`
- [x] Update `Teardown` to destroy the simplified `test_relay` instance (which cleans up the EC2 instance, security groups, and local temp files).
- [x] Retain AWS keypair cleanup.

---

## Detailed Execution Steps

### Step 1: Implement Packaging in `run_tests.sh`
The packaging routine was added to `run_tests.sh` using a robust, exclude-filtered `tar` command instead of `zip`, saving transfer time and maintaining full symbolic links:
```bash
  tar -czf "$tar_file" \
    --exclude='.terraform' \
    --exclude='node_modules' \
    --exclude='test/data' \
    --exclude='test/test_relay/data' \
    .
```

### Step 2: Refactor `test_relay/variables.tf` and `test_relay/main.tf`
- Replaced the local provider with `rancher/file` provider for reliable, cross-platform local-to-remote VM file transfers.
- Streamlined `test_relay/main.tf` by removing legacy nested orchestrator stages.

### Step 3: Implement Remote Docker Execution in `util.go`
- Replaced the buffered `ssh.CheckSSHCommandContextE` with standard `golang.org/x/crypto/ssh` client session execution inside `test/fixtures/util.go`.
- Enabled real-time terminal output streaming of nested container logs.
- Swapped nested container networking to `--network host` for native DNS, zero-overhead routing, and seamless communication.
