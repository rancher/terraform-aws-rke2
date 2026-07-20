#!/usr/bin/env bash
set -euo pipefail

# Color definitions for logging
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

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
  if [[ -f .nix-script.sh ]]; then
    log_info "Cleaning up temporary script: .nix-script.sh"
    rm -f .nix-script.sh
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

  log_info "Preparing temporary Nix runner script..."
  {
    printf "%s\n" "#!/usr/bin/env bash"
    printf "%s\n" "set -euo pipefail"
    printf "printf '%%b[nix-run]%%b Entering Nix development environment...\n' '%s' '%s'\n" "${GREEN}" "${NC}"
    printf "%s\n" "git config --global --add safe.directory \"$PWD\""
    printf "printf '%%b[nix-run]%%b Executing command: %%s\n' '%s' '%s' %q\n" "${GREEN}" "${NC}" "${cmd}"
    printf "%s\n" "$cmd"
  } > .nix-script.sh

  log_info "Executing command inside Nix development environment as user 'suse'..."

  # Run the Nix development environment
  local nix_status=0
  sudo -E -u suse "$NIX_PATH" develop \
    --ignore-environment \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes \
    --keep NIX_SSL_CERT_FILE \
    --keep SSL_CERT_FILE \
    --keep CURL_CA_BUNDLE \
    --keep NIX_ENV_LOADED \
    --keep TERM \
    --keep HOME \
    --keep SSH_AUTH_SOCK \
    --keep GITHUB_TOKEN \
    --keep GITHUB_OWNER \
    --keep AWS_ACCESS_KEY_ID \
    --keep AWS_SECRET_ACCESS_KEY \
    --keep AWS_SESSION_TOKEN \
    --keep AWS_ROLE \
    --keep AWS_REGION \
    --keep AWS_DEFAULT_REGION \
    --keep IDENTIFIER \
    --keep ZONE \
    --keep ACME_SERVER_URL \
    --command bash -e .nix-script.sh || nix_status=$?

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
