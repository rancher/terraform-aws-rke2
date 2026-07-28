# Test Workflow Redesign

**Executed Date:** pending
**Purpose:** Refactor the test relay to act as a generic runner initialized via a zipped copy of the repository. It uses Terratest to orchestrate tests remotely via SSH inside a Docker container (`ci-image`) rather than relying on complex Terraform-in-Terraform orchestration.

---

## 1. High-Level Goals

1. **Decoupled Infrastructure Runner:** 
   Build the test runner as a separate, minimal infrastructure project. This runner will **not** include any Terraform orchestration. It will only provision the compute instance, install Docker, and securely transmit environment variables using the existing `age` provisioning logic. It will support `sles-16` or `ubuntu-24` (defaulting to `ubuntu-24`).
2. **Repository Transfer:** 
   Instead of uploading individual fixture/orchestrator files via Terraform provisioners, we will securely copy a `.zip` file containing the *entire* repository over SSH to the runner. 
3. **Local Perspective Testing:** 
   Refactor the test suites so they are written from the perspective of being run locally. The remote Terratest process will run as if it were a local development machine by executing inside a Docker container based on the official `ci-image`.

---

## 2. Test Workflow Execution

The updated end-to-end workflow executed by `run_tests.sh` and Terratest will be as follows:

1. **Repository Packaging:**
   `run_tests.sh` packs the current entire contents of the repository into a zip file, places it in a location accessible to Terratest, and then executes Terratest.
2. **Fixture Discovery & Subprocessing:**
   The local Terratest process determines which fixtures to test (based on run_tests inputs) and starts subprocesses to run each test in parallel (governed by the defined concurrency setting).
3. **Runner Deployment (Subprocess):**
   In a subprocess, Terratest deploys the `test_relay`.
   The relay deployment involves:
   - Bootstrapping the OS instance.
   - Securely transmitting environment variables/secrets using `age`.
   - Copying the repository `.zip` file over SSH.
   - Installing `docker`.
   - Unpacking the `.zip` file on the remote runner.
4. **Relay Configuration (Subprocess):**
   In another subprocess step, Terratest will SSH into the test relay and configure the OS specifically for the target test fixture (e.g., enabling IPv6 only, adjusting network settings).
5. **Remote Terratest Execution (Subprocess):**
   Terratest will SSH into the relay and start a Docker container using the secure `ci-image` (e.g., `ghcr.io/rancher/ci-image/nix:20260603-18`), mounting the repository workspace, AWS credentials, and Docker socket. It will then execute the "remote Terratest process" inside this container targeting the specific fixture. 
6. **Fixture Testing (Remote):**
   The remote containerized Terratest process will natively handle deploying the fixture infrastructure, running the actual test assertions, reporting results, and tearing down the fixture upon completion.
7. **Result Reporting & Teardown (Local):**
   Once the remote containerized Terratest process exits, the local Terratest orchestrator will capture and report the test results to the user. It will then tear down the `test_relay` instance.
8. **Final Cleanup:**
   `run_tests.sh` finishes by executing the standard `cleanup.sh` script to sweep the AWS account and ensure no orphaned resources or keypairs are left behind.

---

## 3. Implementation Steps & Code Snippets

### Step 3.1: Modify `run_tests.sh` to Package the Repo
Add a compression step before invoking `go test` in the `run_tests.sh` script.

```bash
# In run_tests.sh
echo "Packaging repository for remote test runner..."
ZIP_FILE="/tmp/${IDENTIFIER}_repo.zip"
# Exclude .git and .terraform directories to save transfer time
zip -rq "$ZIP_FILE" . -x "*.git*" "*node_modules*" "*.terraform*" "*terraform.tfstate*"

export TEST_REPO_ZIP="$ZIP_FILE"
```

### Step 3.2: Refactor `test_relay/main.tf`
Remove all the `copy_fixture_template`, `copy_orchestrator`, and `apply`/`destroy` Terraform data blocks. 
Keep only the `runner` module, `access` module, `create_age` for secrets, and `install_dependencies` (which must now only guarantee Docker).

```hcl
# Example slimmed down main.tf provisioner
resource "terraform_data" "install_docker" {
  depends_on = [module.runner]
  # SSH connection block...
  provisioner "remote-exec" {
    inline = [<<-EOT
      # Install Docker and start daemon
      # ... (existing docker install logic)
      # Pre-pull the CI image to avoid pulling it during test execution
      docker pull ghcr.io/rancher/ci-image/nix:20260603-18
    EOT
    ]
  }
}
```

### Step 3.3: Terratest Orchestration Updates
Update the Go Terratest logic to manage the SSH transfer and execute the remote test inside a Docker container on the runner.

```go
// Example pseudo-code for the Go Test execution
func TestRemoteFixture(t *testing.T) {
    // 1. Deploy test_relay
    terraformOptions := GenerateRelayOptions(t)
    terraform.InitAndApply(t, terraformOptions)
    defer terraform.Destroy(t, terraformOptions)

    // 2. SCP the zip file
    serverIP := terraform.Output(t, terraformOptions, "runner_ip")
    scpZipToRunner(t, serverIP, os.Getenv("TEST_REPO_ZIP"))

    // 3. Unzip & Configure
    ssh.CheckSshCommand(t, sshHost, "unzip -q /tmp/repo.zip -d ~/workspace && bash ~/workspace/configure_os.sh")

    // 4. Run Remote Terratest inside the CI Image Docker Container
    remoteCommand := `docker run --rm \
      -v ~/workspace:/workspace \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -w /workspace \
      --env-file ~/secrets.rc \
      ghcr.io/rancher/ci-image/nix:20260603-18 \
      bash -c "nix develop --command 'go test ./test/suite -run TestSpecificFixture'"`
      
    output := ssh.CheckSshCommand(t, sshHost, remoteCommand)
    
    // Log results
    t.Logf("Remote Test Output: %s", output)
}
```

### Step 3.4: Adapt Fixtures for "Local" Execution
Refactor the fixtures to not depend on being wrapped inside `test_relay`. They should simply define the standard RKE2 deployment using normal relative paths (e.g., `source = "../../"`), as the entire repo will exist on the remote runner just like it does locally.
