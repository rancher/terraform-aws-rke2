# Temporary Plan: Refactor test_relay to Resolve CPU Pinning and Replace Local Provider

This temporary plan tracks the step-by-step file-oriented execution for refactoring `test/test_relay` to eliminate redundant nested processes and use the `rancher/file` provider.

## 1. Documentation & Scaffolding
- [x] Create project plan `.agent/plans/RefactorTestRelay.md`
- [x] Create temporary plan `.agent/agent-memory/RefactorTestRelay_temp.md`

## 2. versions.tf Clean-up & Alignment
- [x] Remove `local` provider block from `test/test_relay/versions.tf`
- [x] Align `rancher/file` provider version in root `versions.tf` to `"2.2.1"` to resolve version constraint conflicts
- [x] Align all `versions.tf` to use `version = ">= 2.4.1"` for the flexible, unpinned latest release

## 3. main.tf Refactor
- [x] Replace buggy `file_local_directory` with `terraform_data` using `local-exec` to safely run `mkdir -p`
- [x] Convert `resource "local_file" "terraform_vars"` to `resource "file_local" "terraform_vars"`
- [x] Convert `resource "local_file" "kubeconfig"` to `resource "file_local" "kubeconfig"`
- [x] Convert `resource "local_file" "k8s_key"` to `resource "file_local" "k8s_key"`
- [x] Convert `resource "local_file" "k8s_cert"` to `resource "file_local" "k8s_cert"`
- [x] Convert `resource "local_file" "k8s_ca"` to `resource "file_local" "k8s_ca"`
- [x] Update all occurrences of `local_file.` references to `file_local.` in main.tf
- [x] Simplify `resource "terraform_data" "apply"`'s `remote-exec` script to eliminate the outer double-retry loop
- [x] Add dependency on `file_local.terraform_vars` in `copy_vars` to prevent race conditions during deployment
- [x] Limit execution parallelism using `-parallelism=1` for the orchestrator and sub-modules to eliminate active CPU pinning and prevent Go GC crashes

## 4. outputs.tf Refactor
- [x] Update `test/test_relay/outputs.tf` to reference `file_local.kubeconfig.contents` instead of `local_file.kubeconfig.content`

## 5. Verification & Validation
- [x] Run `terraform fmt` in `test/test_relay`
- [x] Run `terraform validate` in `test/test_relay`
- [x] Identify and revert `getRepoRoot` fallback logic once `.git` folder preservation was verified
- [x] Implement a dedicated `-h` and `--help` option in `run_tests.sh` with modular `display_usage`
- [x] Safeguard nested test VM from self-termination by skipping `run_cleanup` when running inside the relay
- [x] Migrate `INSIDE_RELAY` environment variable detection to standard CLI option `--inside-relay` passed directly to `run_tests.sh`
- [x] Implement automatic sourcing of `secrets.rc` inside `run_tests.sh` to eliminate complex remote container inline wrapper commands
- [x] Refactor SSH execution in `test/fixtures/util.go` using `golang.org/x/crypto/ssh` to stream remote container execution logs in real-time
- [x] Add `-i` and `--identifier` options to `run_tests.sh` to support passing identifiers as CLI arguments rather than container environment variables
- [x] Add `--skip-relay` option to `run_tests.sh` to allow running test fixtures directly from the workstation, bypassing relay VM creation
- [x] Export `INSIDE_RELAY=true` when `inside_relay` is enabled, resolving nested relay VM recreation loops on the remote side
- [x] Refactor remote container execution to use Docker host networking (`--network host`), completely eliminating legacy `resolv.conf` copying, mounting, and cleanup hacks
- [x] Refactor `process_test_results` in `run_tests.sh` to print a beautifully formatted, color-coded summary of passed and failed tests close to the end of the logs
- [x] Dynamically configure `data.http.myip` inside examples to query the IPv6-only endpoint (`https://v6.api.ipinfo.io/ip`) when deploying IPv6 fixtures, resolving external IPv6 resolution failures
- [x] Support bypassing age-decryption inside `create.sh.tpl` and `destroy.sh.tpl` of multi-server deploy modules if active AWS credentials exist in the environment, resolving containerized path resolution failures
- [x] Pass the `-n 5` CLI speed option directly inside `test/fixtures/util.go` to explicitly regulate parallel test execution speed inside the relay
- [x] Validate end-to-end execution of `run_tests.sh -f sles-16-canal-latest-one-tar-ipv4 --half-dry` successfully
