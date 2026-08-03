#!/bin/bash
set -e

# Safely handle Git dubious ownership in containerized/runner environments
git config --global --add safe.directory '*' 2>/dev/null || true

# Configuration flags
rerun_failed=false
specific_test=""
specific_identifier=""
specific_package=""
specific_fixture=""
fixture_group=""
cleanup_id=""
wait_time=""
slow_mode=false
dirty_mode=false
speed_mode="6"
build_only=false
lint_only=false
dry_run=false
half_dry=false
skip_relay=false
inside_relay=false
no_color=false

# Track whether cleanup has run
cleanup_has_run=false

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TEST_DIR=""

# Color definitions for logging
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
CHECK_MARK='\033[1;32m✓\033[0m'
CROSS_MARK='\033[1;31m✗\033[0m'

disable_colors() {
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
  CHECK_MARK='✓'
  CROSS_MARK='✗'
}

# Honor NO_COLOR environment variable if already set
if [ -n "$NO_COLOR" ]; then
  disable_colors
fi

log_info() {
  printf "%b[INFO] [run_tests]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_success() {
  printf "%b[SUCCESS] [run_tests]%b %s\n" "${GREEN}" "${NC}" "$*"
}

log_warning() {
  printf "%b[WARNING] [run_tests]%b %s\n" "${YELLOW}" "${NC}" "$*"
}

log_error() {
  printf "%b[ERROR] [run_tests]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

# Cleanup function that will be called on exit
run_cleanup() {
  # Avoid running cleanup twice
  if [ "$cleanup_has_run" = true ]; then
    return 0
  fi
  cleanup_has_run=true

  if [ "$inside_relay" = true ]; then
    log_info "Running inside relay container. Skipping resource cleanup."
    return 0
  fi

  # Skip if dirty mode or no identifier
  if [ "$dirty_mode" = true ] || [ -z "$IDENTIFIER" ]; then
    return 0
  fi

  log_info "=== Cleanup ==="

  # Wait before cleanup if requested (for investigation)
  if [ -n "$WAIT" ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    log_warning "Tests failed. Waiting $WAIT seconds before cleanup for investigation..."
    sleep "$WAIT"
  fi

  # Check if cleanup script exists
  if [ -f "$REPO_ROOT/cleanup.sh" ]; then
    log_info "Running cleanup script..."
    sh "$REPO_ROOT/cleanup.sh" "$IDENTIFIER"
    cleanup_exit=$?

    if [ $cleanup_exit -ne 0 ]; then
      log_warning "Cleanup failed with exit code $cleanup_exit"
    else
      log_success "Cleanup completed successfully"
    fi
  else
    log_warning "cleanup.sh not found, skipping automated cleanup"
    log_info "You may need to manually clean up resources with ID: $IDENTIFIER"
  fi

  if [ -d "$REPO_ROOT/test/test_relay/.terraform" ]; then
    rm -rf "$REPO_ROOT/test/test_relay/.terraform"
    rm -f "$REPO_ROOT/test/test_relay/.terraform.lock.hcl"
  fi
}

display_usage() {
  cat <<EOT
Usage: $0 [OPTIONS]

Options:
  -r              Re-run failed tests
  -s              Run tests in slow mode (sequential, one at a time)
  -d              Skip cleanup (dirty mode)
  -t TEST         Run specific test (eg. TestMatrix)
  -p PACKAGE      Run specific test package (eg. one)
  -f FIXTURE      Run specific fixture combination (eg. "sle-micro-61-canal-stable-one-rpm-ipv4")
  -g GROUP        Run specific fixture group (eg. "necessary" or "extended")
  -c ID           Cleanup-only mode with the given identifier
  -i IDENTIFIER   Set a specific test identifier (eg. "YS-xyz")
  -w SECONDS      Wait time in seconds before cleanup on test failure (for investigation)
  -n SPEED        Set the number of consecutive tests and test packages (speed)
  -h, --help      Display this help message and exit
  --build-only    Build up the global plugin cache and validate examples, then exit
  --lint-only     Run the lint action and then exit
  --dry-run       Run in dry-run mode (do not deploy any AWS resources)
  --half-dry      Run in half-dry mode (deploy relay VM, but skip RKE2 fixture)
  --skip-relay    Skip relay packaging and run tests directly on workstation
  --inside-relay  Indicate the script is running inside the testing runner
  --no-color      Disable color output (respects standard NO_COLOR env var too)

Notes:
  - Only one of -c, -t, -p, -f, -g, --build-only, or --lint-only can be used at a time
  - The -f option sets the COMBO environment variable for fixture selection
  - The -g option sets the GROUP environment variable for fixture group selection
  - The -w option sets the WAIT environment variable for error investigation
EOT
}

parse_options() {
  local OPTIND=1
  # Parse command line options
  while getopts ":rsdt:p:f:g:c:w:n:hi:-:" opt; do
    case $opt in
      r) rerun_failed=true ;;
      t) specific_test="$OPTARG" ;;
      p) specific_package="$OPTARG" ;;
      f) specific_fixture="$OPTARG" ;;
      g) fixture_group="$OPTARG" ;;
      c) cleanup_id="$OPTARG" ;;
      i) specific_identifier="$OPTARG" ;;
      w) wait_time="$OPTARG" ;;
      d) dirty_mode=true ;;
      n) speed_mode="$OPTARG" ;;
      s) slow_mode=true ;;
      h) display_usage; exit 0 ;;
      -)
        case "${OPTARG}" in
          build-only) build_only=true ;;
          lint-only) lint_only=true ;;
          dry-run) dry_run=true ;;
          half-dry) half_dry=true ;;
          skip-relay) skip_relay=true ;;
          inside-relay) inside_relay=true ;;
          no-color) no_color=true; disable_colors ;;
          help) display_usage; exit 0 ;;
          identifier)
            specific_identifier="${!OPTIND}"
            OPTIND=$((OPTIND + 1))
            ;;
          *) log_error "Invalid option: --${OPTARG}"; display_usage >&2; exit 1 ;;
        esac
        ;;
      \?)
        log_error "Invalid option: -$OPTARG"
        display_usage >&2
        exit 1
        ;;
    esac
  done
}

validate_options() {
  # Validate mutually exclusive options
  local exclusive_count=0
  [ -n "$cleanup_id" ] && exclusive_count=$((exclusive_count + 1))
  [ -n "$specific_test" ] && exclusive_count=$((exclusive_count + 1))
  [ -n "$specific_package" ] && exclusive_count=$((exclusive_count + 1))
  [ -n "$specific_fixture" ] && exclusive_count=$((exclusive_count + 1))
  [ -n "$fixture_group" ] && exclusive_count=$((exclusive_count + 1))
  [ "$build_only" = true ] && exclusive_count=$((exclusive_count + 1))
  [ "$lint_only" = true ] && exclusive_count=$((exclusive_count + 1))

  if [ $exclusive_count -gt 1 ]; then
    log_error "Only one of -c, -t, -p, -f, -g, --build-only, or --lint-only can be used at a time."
    exit 1
  fi
}

display_configuration() {
  # Display configuration
  log_info "=== Test Configuration ==="
  if [ "$slow_mode" = true ]; then
    log_info "Mode: Slow (sequential execution to avoid AWS rate limiting)"
  elif [ -n "$speed_mode" ]; then
    log_info "Mode: Custom speed ($speed_mode parallel execution)"
  else
    log_info "Mode: Normal (parallel execution)"
  fi

  if [ "$rerun_failed" = true ]; then
    log_info "Rerun failed tests: Enabled"
  fi

  if [ "$dirty_mode" = true ]; then
    log_info "Cleanup: Disabled (dirty mode)"
  else
    log_info "Cleanup: Enabled"
  fi

  if [ -n "$specific_test" ]; then
    log_info "Specific test: $specific_test"
  fi

  if [ -n "$specific_package" ]; then
    log_info "Specific package: $specific_package"
  fi

  if [ -n "$specific_fixture" ]; then
    log_info "Specific fixture: $specific_fixture"
  fi

  if [ -n "$fixture_group" ]; then
    log_info "Fixture group: $fixture_group"
  fi

  if [ -n "$cleanup_id" ]; then
    log_info "Cleanup-only mode: $cleanup_id"
  fi

  if [ -n "$wait_time" ]; then
    log_info "Wait time on failure: $wait_time seconds"
  fi

  if [ "$build_only" = true ]; then
    log_info "Build-only mode: Enabled"
  fi

  if [ "$lint_only" = true ]; then
    log_info "Lint-only mode: Enabled"
  fi

  if [ "$dry_run" = true ]; then
    log_info "Dry-run mode: Enabled"
  fi

  if [ "$half_dry" = true ]; then
    log_info "Half-dry mode: Enabled"
  fi

  if [ "$inside_relay" = true ]; then
    log_info "Inside Relay: Enabled"
  fi

  log_info "=========================="
}

setup_environment() {
  # If inside-relay is true, then skip-relay must automatically be true
  if [ "$inside_relay" = true ]; then
    skip_relay=true
  fi

  # Look for and source secrets.rc if it exists
  if [ -f "$REPO_ROOT/secrets.rc" ]; then
    log_info "Sourcing secrets.rc from repository root..."
    # shellcheck disable=SC1090,SC1091
    source "$REPO_ROOT/secrets.rc"
  elif [ -f "./secrets.rc" ]; then
    log_info "Sourcing secrets.rc from current directory..."
    # shellcheck disable=SC1090,SC1091
    source "./secrets.rc"
  fi

  # Set cleanup ID if provided
  if [ -n "$cleanup_id" ]; then
    export IDENTIFIER="$cleanup_id"
  fi

  # Set specific identifier if provided
  if [ -n "$specific_identifier" ]; then
    export IDENTIFIER="$specific_identifier"
  fi

  # Set COMBO environment variable for fixture selection
  export COMBO="$specific_fixture"
  if [ -n "$COMBO" ]; then
    log_info "COMBO environment variable set to: $COMBO"
  fi

  # Set GROUP environment variable for fixture group selection
  export GROUP="$fixture_group"
  if [ -n "$GROUP" ]; then
    log_info "GROUP environment variable set to: $GROUP"
  fi

  # Set WAIT environment variable for error investigation
  export WAIT="$wait_time"
  if [ -n "$WAIT" ]; then
    log_info "WAIT environment variable set to: $WAIT seconds"
  fi

  if [ "$dry_run" = true ]; then
    export DRY_RUN=true
    log_info "DRY_RUN environment variable exported"
  fi

  if [ "$half_dry" = true ]; then
    export HALF_DRY=true
    log_info "HALF_DRY environment variable exported"
  fi

  if [ "$inside_relay" = true ]; then
    export INSIDE_RELAY=true
    log_info "INSIDE_RELAY environment variable exported"
  fi

  if [ "$dirty_mode" = true ]; then
    export DIRTY_MODE=true
    log_info "DIRTY_MODE environment variable exported"
  fi

  # Locate repository root
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  # Generate and export identifier
  if [ -z "$IDENTIFIER" ]; then
    IDENTIFIER="$(echo "a-$RANDOM-d" | base64 | tr -d '=')"
    export IDENTIFIER
  fi

  log_info "Test identifier: $IDENTIFIER"
}

# Find the tests directory
find_test_dir() {
  local test_dir=""
  if [ -d "$REPO_ROOT/test/tests" ]; then
    test_dir="test/tests"
  elif [ -d "$REPO_ROOT/tests" ]; then
    test_dir="tests"
  elif [ -d "$REPO_ROOT/test" ]; then
    test_dir="test"
  else
    log_error "Unable to find tests directory"
    exit 1
  fi
  echo "$test_dir"
}

process_test_results() {
  local log_file="/tmp/${IDENTIFIER}_test.log"
  local fail_file="/tmp/${IDENTIFIER}_failed_tests.txt"
  local fail_pkg_file="/tmp/${IDENTIFIER}_failed_packages.txt"

  if [ ! -f "$log_file" ] || ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  log_info "=== Test Outcome Summary ==="

  local passed failed_tests failed_packages
  passed="$(jq -r '. | select(.Action == "pass") | select(.Test != null).Test' "$log_file" 2>/dev/null | sort -u | grep -v '^[[:space:]]*$' || true)"
  failed_tests="$(jq -r '. | select(.Action == "fail") | select(.Test != null).Test' "$log_file" 2>/dev/null | sort -u | grep -v '^[[:space:]]*$' || true)"
  failed_packages="$(jq -r '. | select(.Action == "fail") | select(.Test == null).Package' "$log_file" 2>/dev/null | sort -u | grep -v '^[[:space:]]*$' || true)"

  if [ -n "$passed" ]; then
    log_success "PASSED TESTS:"
    while IFS= read -r test_name; do
      if [ -n "$test_name" ]; then
        printf "  %b %s\n" "${CHECK_MARK}" "$test_name"
      fi
    done <<< "$passed"
  fi

  if [ -n "$failed_tests" ] || [ -n "$failed_packages" ]; then
    log_error "FAILED ITEMS:"
    if [ -n "$failed_tests" ]; then
      while IFS= read -r test_name; do
        if [ -n "$test_name" ]; then
          printf "  %b %s\n" "${CROSS_MARK}" "$test_name"
        fi
      done <<< "$failed_tests"
      echo "$failed_tests" > "$fail_file"
    else
      rm -f "$fail_file"
    fi

    if [ -n "$failed_packages" ]; then
      while IFS= read -r pkg_name; do
        if [ -n "$pkg_name" ]; then
          printf "  %b Package: %s\n" "${CROSS_MARK}" "$pkg_name"
        fi
      done <<< "$failed_packages"
      echo "$failed_packages" > "$fail_pkg_file"
    else
      rm -f "$fail_pkg_file"
    fi
  else
    rm -f "$fail_file"
    rm -f "$fail_pkg_file"
  fi

  log_info "============================"
}

execute_gotestsum() {
  local package_pattern="$1"
  local parallel_packages="$2"
  local parallel_tests="$3"
  local rerun_flag="$4"
  local specific_test_flag="$5"

  local args=(
    "--format=standard-verbose"
    "--jsonfile" "/tmp/${IDENTIFIER}_test.log"
  )

  args+=(
    "--packages" "$REPO_ROOT/$TEST_DIR/$package_pattern"
    "--"
    "-count=1"
    "-timeout=300m"
    "-failfast"
  )

  [ -n "$parallel_packages" ] && args+=("$parallel_packages")
  [ -n "$parallel_tests" ] && args+=("$parallel_tests")
  [ -n "$rerun_flag" ] && args+=("$rerun_flag")
  [ -n "$specific_test_flag" ] && args+=("$specific_test_flag")

  # Display the command that will be run (quoting arguments with spaces)
  local printable_args=()
  for arg in "${args[@]}"; do
    if [[ "$arg" == *" "* ]]; then
      printable_args+=("'$arg'")
    else
      printable_args+=("$arg")
    fi
  done

  log_info "Test command:"
  log_info "  gotestsum ${printable_args[*]}"

  # Run tests
  gotestsum "${args[@]}"
}

# Run tests function
run_tests() {
  local rerun=$1
  local slow_mode=$2

  if [ "$skip_relay" = true ]; then
    log_info "Skip Packaging: Enabled. Skipping repository packaging."
  else
    # Package the repository for remote execution
    log_info "Packaging repository for remote execution..."
    local tar_file="/tmp/${IDENTIFIER}_repo.tar.gz"
    rm -f "$tar_file"
    pushd "$REPO_ROOT" > /dev/null
    tar -czf "$tar_file" \
      --exclude='.terraform' \
      --exclude='node_modules' \
      --exclude='test/data' \
      --exclude='test/test_relay/data' \
      .
    popd > /dev/null
    export TEST_REPO_ZIP="$tar_file"
    log_success "Repository packaged successfully: $TEST_REPO_ZIP"
  fi

  export NO_COLOR=1
  log_info "Starting tests..."
  cd "$REPO_ROOT/$TEST_DIR" || exit 1

  # Build rerun flag
  local rerun_flag=""
  if [ "$rerun" = true ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    rerun_flag="-run=$(tr '\n' '|' < "/tmp/${IDENTIFIER}_failed_tests.txt" | sed 's/|$//')"
    log_info "Rerunning failed tests: $rerun_flag"
  fi

  # Build specific test flag
  local specific_test_flag=""
  if [ -n "$specific_test" ] && [ "$rerun" != true ]; then
    specific_test_flag="-run=$specific_test"
    log_info "Running specific test: $specific_test"
  fi

  # Build package pattern
  local package_pattern=""
  if [ -n "$specific_package" ]; then
    package_pattern="$specific_package"
    log_info "Running specific package: $specific_package"
  else
    package_pattern="..."
  fi

  # Build parallel flags for slow mode
  local parallel_packages=""
  local parallel_tests=""
  if [ "$slow_mode" = true ]; then
    log_info "Slow mode: Running tests sequentially"
    parallel_packages="-p=1"
    parallel_tests="-parallel=1"
  elif [ -n "$speed_mode" ]; then
    log_info "Custom speed: Running $speed_mode tests in parallel"
    parallel_packages="-p=$speed_mode"
    parallel_tests="-parallel=$speed_mode"
  fi

  local exit_code=0
  execute_gotestsum "$package_pattern" "$parallel_packages" "$parallel_tests" "$rerun_flag" "$specific_test_flag" || exit_code=$?

  process_test_results

  return $exit_code
}

check_environment() {
  # Check required environment variables
  log_info "=== Environment Check ==="
  if [ -z "$GITHUB_TOKEN" ]; then
    log_warning "GITHUB_TOKEN is not set"
  else
    log_success "GITHUB_TOKEN: Set"
  fi

  if [ -z "$GITHUB_OWNER" ]; then
    log_warning "GITHUB_OWNER is not set"
  else
    log_success "GITHUB_OWNER: Set ($GITHUB_OWNER)"
  fi

  if [ -z "$ZONE" ]; then
    log_warning "ZONE is not set"
  else
    log_success "ZONE: Set"
  fi
  log_info "========================="
}

pre_test_validation() {
  if [ "$inside_relay" = true ]; then
    log_info "Running inside relay container. Skipping test validation (it was already validated)."
    return 0
  fi
  local current_dir
  current_dir="$(pwd)"

  log_info "=== Pre-Test Validation ==="

  log_info "Running go mod tidy..."
  cd "$REPO_ROOT/$TEST_DIR" || exit 1
  if ! go mod tidy; then
    log_error "go mod tidy failed"
    exit 1
  fi
  log_success "go mod tidy passed"

  log_info "Formatting tests..."
  gofmt -s -w -e .
  log_success "Formatting complete"

  log_info "Checking for compile errors..."
  while IFS= read -r dir; do
    if [ -n "$dir" ]; then
      if ! go test -c "$dir" -o /dev/null 2>&1; then
        log_error "Failed to compile package in $dir"
        exit 1
      fi
    fi
  done <<< "$(find "$REPO_ROOT/$TEST_DIR" -not \( -path "*/.terraform*" -prune \) -not \( -path "$REPO_ROOT/$TEST_DIR/data" -prune \) -name '*.go' -exec dirname {} \; | sort -u)"
  log_success "Compile checks passed"

  log_info "Running go lint..."
  if ! golangci-lint run -c "$REPO_ROOT/.golangci.yml"; then
    log_error "Linting failed"
    exit 1
  fi
  log_success "Lint passed"

  cd "$current_dir" || exit 1

  log_info "Checking terraform configs..."
  if ! tflint --recursive; then
    log_error "tflint failed"
    exit 1
  fi
  log_success "Terraform configs valid"

  log_info "Running actionlint..."
  if ! actionlint; then
    log_error "actionlint failed"
    exit 1
  fi
  log_success "actionlint passed"

  log_info "Running shellcheck..."
  if ! find . -name "*.sh" -not -path "*/.terraform/*" -not -path "*/test/data/*" -exec shellcheck {} +; then
    log_error "shellcheck failed"
    exit 1
  fi
  log_success "shellcheck passed"

  log_info "Running npm install..."
  if [ -f "package.json" ]; then
    npm install --no-fund --no-audit || log_warning "npm install failed, eslint may fail"
  else
    # Install required eslint packages directly if package.json is missing
    npm install --no-save @eslint/js globals eslint || log_warning "npm install failed, eslint may fail"
  fi

  log_info "Running eslint..."
  if ! eslint .; then
    log_error "eslint failed"
    exit 1
  fi
  log_success "eslint passed"

  log_info "============================"
}

execute_tests() {
  # Clear failed tests before initial run
  rm -f "/tmp/${IDENTIFIER}_failed_tests.txt"
  export TESTS_PASSED=true

  # Run tests initially
  log_info "=== Running Tests ==="
  run_tests false "$slow_mode"
  test_exit_code=$?

  if [ $test_exit_code -ne 0 ]; then
    log_warning "Tests failed with exit code: $test_exit_code"
    TESTS_PASSED=false
  else
    log_success "Tests passed"
    TESTS_PASSED=true
  fi

  # Brief pause between test runs
  sleep 5

  # Check if we need to rerun failed tests
  if [ "$rerun_failed" = true ] && [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
    log_info "=== Rerunning Failed Tests ==="
    run_tests true "$slow_mode"
    test_exit_code=$?

    if [ $test_exit_code -ne 0 ]; then
      log_error "Rerun failed with exit code: $test_exit_code"
      TESTS_PASSED=false
    else
      log_success "All tests passed on rerun"
      TESTS_PASSED=true
    fi

    sleep 5
  fi
}

display_summary() {
  log_info "=== Test Summary ==="

  # Exit with appropriate code based on test results
  if [ "$TESTS_PASSED" = false ]; then
    log_error "Tests FAILED"

    if [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ] || [ -f "/tmp/${IDENTIFIER}_failed_packages.txt" ]; then
      log_error "Failed items:"
      if [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
        while IFS= read -r test_name; do
          if [ -n "$test_name" ]; then
            printf "  %b %s\n" "${CROSS_MARK}" "${test_name}"
          fi
        done < "/tmp/${IDENTIFIER}_failed_tests.txt"
      fi
      if [ -f "/tmp/${IDENTIFIER}_failed_packages.txt" ]; then
        while IFS= read -r pkg_name; do
          if [ -n "$pkg_name" ]; then
            printf "  %b Package: %s\n" "${CROSS_MARK}" "${pkg_name}"
          fi
        done < "/tmp/${IDENTIFIER}_failed_packages.txt"
      fi
    else
      log_error "No specific failed tests or packages logged, but the exit code was non-zero."
    fi

    if [ -f "/tmp/${IDENTIFIER}_failed_tests.txt" ]; then
      log_error "Failed tests logged to: /tmp/${IDENTIFIER}_failed_tests.txt"
    fi
    exit 1
  else
    log_success "All tests PASSED"
    exit 0
  fi
}

prime_plugin_cache() {
  log_info "=== Prime Plugin Cache ==="
  log_info "priming terraform plugin cache..."
  export GLOBAL_TF_PLUGIN_CACHE="$HOME/.terraform.d/plugin-cache"
  mkdir -p "$GLOBAL_TF_PLUGIN_CACHE"
  export TF_PLUGIN_CACHE_DIR="$GLOBAL_TF_PLUGIN_CACHE"
  while IFS= read -r dir; do
    pushd "$dir" > /dev/null || exit

    needs_mirror=false

    (terraform get > /dev/null 2>&1 || true)
    providers=$(terraform providers | grep provider | awk -F'provider' '{print $2}' | awk -F'[' '{print $2}' | awk -F']' '{print $1}' | sort | uniq || true)

    for p in $providers; do
      if [ "$p" = "terraform.io/builtin/terraform" ]; then
        continue
      fi
      if [ ! -d "$GLOBAL_TF_PLUGIN_CACHE/$p" ]; then
        log_info "Global cache doesn't have provider: $p"
        needs_mirror=true
        break
      fi
    done

    if $needs_mirror; then
      log_info "  running 'terraform providers mirror $GLOBAL_TF_PLUGIN_CACHE' in $dir..."
      (terraform providers mirror "$GLOBAL_TF_PLUGIN_CACHE" > /dev/null 2>&1 || true)
    fi
    rm -rf .terraform

    popd > /dev/null || exit
  done <<< "$(find "$REPO_ROOT/examples" -name 'main.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)"
  unset TF_PLUGIN_CACHE_DIR
}

validate_examples() {
  log_info "=== Validate Examples ==="
  export GLOBAL_TF_PLUGIN_CACHE="$HOME/.terraform.d/plugin-cache"
  export TF_PLUGIN_CACHE_DIR="$GLOBAL_TF_PLUGIN_CACHE"

  while IFS= read -r dir; do
    pushd "$dir" > /dev/null || exit 1
    log_info "  validating example in $dir..."

    (terraform init -backend=false > /dev/null 2>&1 || true)
    if ! terraform validate; then
      log_error "Terraform validation failed in $dir"
      popd > /dev/null || exit 1
      exit 1
    fi
    rm -rf .terraform
    rm -f .terraform.lock.hcl
    popd > /dev/null || exit 1
  done <<< "$(find "$REPO_ROOT/examples" -name 'main.tf' -not -path '*/.terraform/*' -exec dirname {} \; | sort -u)"
  log_success "All examples validated successfully"
}

main() {
  parse_options "$@"
  validate_options

  # Handle no-color option and environment variable
  if [ "$no_color" = true ] || [ -n "${NO_COLOR:-}" ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
    CHECK_MARK='✓'
    CROSS_MARK='✗'
  fi

  # Set trap to run cleanup on exit, error, interrupt, or termination
  trap run_cleanup EXIT ERR INT TERM

  display_configuration

  if [ "$lint_only" = true ]; then
    log_info "Lint-only mode enabled, skipping tests and cleanup..."
    TEST_DIR="$(find_test_dir)"
    dirty_mode=true # Skip cleanup
    pre_test_validation
    validate_examples
    log_success "Lint-only mode completed successfully"
    exit 0
  fi

  if [ "$build_only" = true ]; then
    log_info "Build-only mode enabled, skipping tests and cleanup..."
    dirty_mode=true # Skip cleanup
    prime_plugin_cache
    log_success "Build-only mode completed successfully"
    exit 0
  fi

  prime_plugin_cache
  setup_environment

  TEST_DIR="$(find_test_dir)"
  log_info "Using test directory: $TEST_DIR"

  check_environment

  # If cleanup-only mode, skip tests and run cleanup directly
  if [ -n "$cleanup_id" ]; then
    log_info "Cleanup-only mode enabled, skipping tests..."
    # In cleanup-only mode, we want to run cleanup immediately
    run_cleanup
    log_success "Cleanup-only mode completed"
    exit 0
  fi

  pre_test_validation
  execute_tests
  display_summary
}

main "$@"
