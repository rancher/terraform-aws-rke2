#!/usr/bin/env bash
set -euo pipefail

# Color definitions for logging
if [[ -n "${NO_COLOR:-}" ]]; then
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
else
  RED='\033[1;31m'
  GREEN='\033[1;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[1;34m'
  NC='\033[0m' # No Color
fi

log_info() {
  printf "%b[INFO] [nix-run]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_success() {
  printf "%b[SUCCESS] [nix-run]%b %s\n" "${GREEN}" "${NC}" "$*"
}

log_warning() {
  printf "%b[WARNING] [nix-run]%b %s\n" "${YELLOW}" "${NC}" "$*"
}

log_error() {
  printf "%b[ERROR] [nix-run]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

cleanup() {
  local exit_code=$?
  if [[ -f /tmp/.nix-script.sh ]]; then
    log_info "Cleaning up temporary script: /tmp/.nix-script.sh"
    rm -f /tmp/.nix-script.sh
  fi
  if [[ -f /tmp/.nix-entered ]]; then
    log_info "Cleaning up temporary canary: /tmp/.nix-entered"
    rm -f /tmp/.nix-entered
  fi
  if [[ "$exit_code" -ne 0 ]]; then
    log_error "nix-run.sh failed with exit code $exit_code"
  else
    log_success "nix-run.sh completed successfully."
  fi
  exit "$exit_code"
}

find_certificates() {
  log_info "Searching for CA certificate file..."
  if [[ -n "${NIX_SSL_CERT_FILE:-}" ]]; then
    log_info "NIX_SSL_CERT_FILE is already defined: ${NIX_SSL_CERT_FILE}"
    return 0
  fi

  local certs=(
    "/etc/ssl/certs/ca-certificates.crt"
    "/etc/ssl/certs/ca-bundle.crt"
    "/etc/pki/tls/certs/ca-bundle.crt"
    "/etc/ssl/ca-bundle.pem"
    "/var/lib/ca-certificates/ca-bundle.pem"
  )

  for cert in "${certs[@]}"; do
    if [[ -f "$cert" ]]; then
      export NIX_SSL_CERT_FILE="$cert"
      log_success "Located CA certificates: ${NIX_SSL_CERT_FILE}"
      break
    fi
  done

  if [[ -z "${NIX_SSL_CERT_FILE:-}" ]]; then
    log_warning "No CA certificate file found. Nix downloads may fail."
  fi

  export SSL_CERT_FILE="${NIX_SSL_CERT_FILE:-}"
  export CURL_CA_BUNDLE="${NIX_SSL_CERT_FILE:-}"
}

verify_environment() {
  log_info "Verifying execution environment prerequisites..."

  if ! id -u suse >/dev/null 2>&1; then
    log_error "User 'suse' does not exist. 'nix-run.sh' must be run in an environment with the 'suse' user configured."
    return 1
  fi
  log_success "Verified user 'suse' exists."

  NIX_PATH="/home/suse/.nix-profile/bin/nix"
  if [[ ! -x "$NIX_PATH" ]]; then
    log_warning "Nix executable not found at preferred path: ${NIX_PATH}"
    if command -v nix >/dev/null 2>&1; then
      NIX_PATH="$(command -v nix)"
      log_success "Found nix executable in PATH: ${NIX_PATH}"
    else
      log_error "Nix executable could not be found at ${NIX_PATH} or in PATH."
      return 1
    fi
  else
    log_success "Verified Nix executable exists at: ${NIX_PATH}"
  fi
}

adjust_permissions() {
  log_info "Adjusting workspace ownership and permissions..."

  # Ensure the suse user can read/write the script and current directory
  log_info "Setting ownership of current directory recursively to suse:suse..."
  if ! chown -R suse:suse . 2>/dev/null; then
    log_warning "Failed to recursively change some file ownership to suse:suse. Execution will proceed."
  fi

  # Ensure parent directories are traversable by the suse user
  log_info "Checking and making parent directories traversable by 'suse' user..."
  local p="$PWD"
  while [[ "$p" != "/" ]] && [[ -n "$p" ]]; do
    if ! chmod a+rx "$p" 2>/dev/null; then
      log_warning "Could not set read/execute permissions on parent directory: ${p}"
    fi
    p="$(dirname "$p")"
  done
  log_success "Permissions adjusted successfully."
}

run_nix_command() {
  local cmd="$*"
  if [[ -z "$cmd" ]]; then
    log_error "No command provided to run in Nix environment."
    return 1
  fi

  # Pre-configure Git to trust all directories globally for both root and suse users to prevent Nix/Git ownership crashes (exit 128)
  log_info "Pre-configuring Git safe directories..."
  git config --global --add safe.directory '*' 2>/dev/null || true
  sudo -E -u suse git config --global --add safe.directory '*' 2>/dev/null || true

  # Detect and output environment variables that will be suppressed by --ignore-environment
  local kept_vars=(
    "NIX_SSL_CERT_FILE"
    "SSL_CERT_FILE"
    "CURL_CA_BUNDLE"
    "NIX_ENV_LOADED"
    "INSIDE_RELAY"
    "TERM"
    "HOME"
    "SSH_AUTH_SOCK"
    "GITHUB_TOKEN"
    "GITHUB_OWNER"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_SESSION_TOKEN"
    "AWS_ROLE"
    "AWS_REGION"
    "AWS_DEFAULT_REGION"
    "IDENTIFIER"
    "ZONE"
    "ACME_SERVER_URL"
    "NO_COLOR"
  )
  local suppressed_vars=()
  while IFS= read -r var; do
    if [[ -n "$var" ]]; then
      local kept=false
      for k in "${kept_vars[@]}"; do
        if [[ "$k" == "$var" ]]; then
          kept=true
          break
        fi
      done
      if [[ "$kept" == "false" ]] && [[ ! "$var" =~ ^(BASH_|SHELL|UID|EUID|PPID|IFS|PWD|OLDPWD|SHLVL|TERM_|NIX_PATH|PATH|_) ]]; then
        suppressed_vars+=("$var")
      fi
    fi
  done < <(compgen -e)

  if [[ ${#suppressed_vars[@]} -gt 0 ]]; then
    log_warning "The following environment variables will be suppressed/ignored inside the Nix shell environment:"
    for var in "${suppressed_vars[@]}"; do
      echo "  - ${var}"
    done
  fi

  # Build the --keep arguments dynamically from the master list
  local keep_args=()
  for var in "${kept_vars[@]}"; do
    keep_args+=("--keep" "$var")
  done

  log_info "Preparing temporary Nix runner script..."
  local temp_script="/tmp/.nix-script.sh"
  local temp_entered="/tmp/.nix-entered"

  # Ensure any old ones are removed
  rm -f "$temp_script" "$temp_entered"

  {
    printf "%s\n" "#!/usr/bin/env bash"
    printf "%s\n" "set -euo pipefail"
    printf "%s\n" "touch ${temp_entered}"
    printf "printf '%%b[nix-run]%%b Entering Nix development environment...\n' '%s' '%s'\n" "${GREEN}" "${NC}"
    printf "%s\n" "git config --global --add safe.directory \"$PWD\""
    printf "printf '%%b[nix-run]%%b Executing command: %%s\n' '%s' '%s' %q\n" "${GREEN}" "${NC}" "${cmd}"
    printf "%s\n" "$cmd"
  } > "$temp_script"

  # Ensure the suse user can read and execute the script
  chown suse:suse "$temp_script" 2>/dev/null || true
  chmod a+rx "$temp_script" 2>/dev/null || true

  # Run the Nix development environment with retries for environment setup failures
  local max_attempts=5
  local attempt=1
  local nix_status=0

  while [[ ${attempt} -le ${max_attempts} ]]; do
    if [[ -f "$temp_entered" ]]; then
      rm -f "$temp_entered"
    fi

    log_info "Executing command inside Nix development environment as user 'suse' (attempt ${attempt}/${max_attempts})...."

    nix_status=0
    sudo -E -u suse "$NIX_PATH" develop \
      --ignore-environment \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes \
      "${keep_args[@]}" \
      --command bash -e "$temp_script" || nix_status=$?

    if [[ "$nix_status" -eq 0 ]]; then
      log_success "Nix command execution succeeded."
      break
    fi

    # Check if the environment was entered successfully
    if [[ -f "$temp_entered" ]]; then
      log_error "Nix environment entered, but command script failed. Skipping environment retries."
      break
    fi

    log_warning "Nix environment startup failed on attempt ${attempt}."
    if [[ ${attempt} -lt ${max_attempts} ]]; then
      local delay=$(( attempt * 5 ))
      log_info "Retrying Nix startup in ${delay} seconds..."
      sleep "${delay}"
    fi
    attempt=$(( attempt + 1 ))
  done

  if [[ "$nix_status" -ne 0 ]]; then
    echo ""
    echo "========================================================================"
    log_error "Nix environment or script execution failed with exit code ${nix_status}."
    log_error "Troubleshooting Diagnostics:"
    echo "1. If you didn't see 'Entering Nix development environment...', the error happened BEFORE entering Nix."
    echo "   - Verify if flake.nix is valid by running: nix flake check"
    echo "   - Check if there are network issues downloading Nix packages."
    echo "   - Check permissions of the /home/suse directory."
    echo "2. If you saw 'Entering Nix development environment...' but NOT 'Executing command...', the error was in environment initialization."
    echo "3. If you saw 'Executing command...', the command itself failed inside the environment."
    echo "   - Command executed: ${cmd}"
    echo "========================================================================"
    echo ""
    return "$nix_status"
  fi
}

main() {
  if [[ $# -eq 0 ]]; then
    log_error "No command provided."
    echo "Usage: $0 \"<command>\""
    exit 1
  fi

  trap cleanup EXIT

  find_certificates
  verify_environment
  adjust_permissions
  run_nix_command "$@"
}

main "$@"
